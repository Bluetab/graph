defmodule Graph.CrossingReduction do
  @moduledoc """
  Implementation of clustered crossing reduction.
  """

  alias Graph.ClusteredLevelGraph
  alias Graph.ClusterTree
  alias Graph.ConstrainedCrossingReduction
  alias Graph.ConstraintGraph
  alias Graph.CrossingReductionGraph
  alias Graph.LevelGraph
  alias Graph.NestingGraph
  alias Graph.Traversal

  require Logger

  @type vertex :: Graph.Vertex.id()
  @type direction :: :down | :up
  @type permutation :: [vertex]

  @typep edge :: {vertex, vertex}
  @typep constraint_map :: %{vertex: Graph.t()}
  @typep crossing_reduction_map :: %{vertex: CrossingReductionGraph.t()}

  @spec crossing_reduction_graphs(ClusteredLevelGraph.t(), direction) :: crossing_reduction_map
  def crossing_reduction_graphs(%ClusteredLevelGraph{g: %{g: g}} = clg, direction \\ :down) do
    [{_, t1}, {_, t2}] =
      clg
      |> ClusteredLevelGraph.level_cluster_trees(contracted: false)
      |> Enum.sort_by(&elem(&1, 0), sorter(direction))

    constraints = constraints(clg, t1)

    t1
    |> ClusterTree.leaves()
    |> Enum.map(&{&1, %{b: Graph.vertex(g, &1, :b), r: 1}})
    |> do_crossing_reduction_graphs(clg, t2, direction, constraints)
  end

  @spec permute(crossing_reduction_map, vertex) :: permutation
  def permute(%{} = crgs, root) do
    do_permute(crgs, root)
  end

  @spec do_permute(crossing_reduction_map, vertex) :: permutation
  defp do_permute(%{} = crgs, w) do
    case Map.get(crgs, w) do
      nil ->
        [w]

      %CrossingReductionGraph{g: lg, gc: gc} ->
        lg
        |> ConstrainedCrossingReduction.permute(gc, 2)
        |> reorder_border_nodes(w)
        |> Enum.flat_map(&do_permute(crgs, &1))
    end
  end

  @spec reorder_border_nodes(permutation, vertex) :: permutation
  defp reorder_border_nodes(els, w) do
    Enum.sort_by(els, fn
      {:l, ^w, _} -> 0
      {:r, ^w, _} -> 2
      _ -> 1
    end)
  end

  @spec constraints(ClusteredLevelGraph.t(), Graph.t()) :: constraint_map
  defp constraints(%ClusteredLevelGraph{g: %{g: g}, t: t} = clg, %Graph{} = t1) do
    t
    |> ClusterTree.clusters()
    |> Enum.group_by(&ClusteredLevelGraph.levels(clg, &1))
    |> Enum.filter(fn {span, _} -> MapSet.size(span) > 1 end)
    |> Enum.flat_map(fn {_, cs} -> cs end)
    |> Enum.group_by(&Graph.in_neighbours(t, &1))
    |> Enum.reject(fn {parents, children} -> parents == [] or Enum.count(children) < 2 end)
    |> Enum.map(fn {[parent], children} -> {parent, children} end)
    |> Map.new(fn {parent, children} -> {parent, constraint_graph(children, t1, g)} end)
  end

  @spec constraint_graph([vertex], Graph.t(), Graph.t()) :: Graph.t()
  defp constraint_graph(cs, %Graph{} = t1, %Graph{} = g) do
    cs
    |> Enum.sort_by(&order(t1, g, &1))
    |> Enum.chunk_every(2, 1, :discard)
    |> ConstraintGraph.new()
  end

  @spec order(Graph.t(), Graph.t(), vertex) :: float
  defp order(%Graph{} = t1, %Graph{} = g, c) do
    [c]
    |> Traversal.reachable(t1)
    |> Enum.filter(&(Graph.out_degree(t1, &1) == 0))
    |> Enum.map(&Graph.vertex_label(g, &1))
    |> Enum.map(&Map.get(&1, :b))
    |> Enum.reduce({0, 0}, fn b, {sum, count} -> {sum + b, count + 1} end)
    |> then(fn {sum, count} -> sum / count end)
  end

  @spec do_crossing_reduction_graphs(
          permutation,
          ClusteredLevelGraph.t(),
          Graph.t(),
          direction,
          constraint_map
        ) :: crossing_reduction_map
  defp do_crossing_reduction_graphs(
         v1s,
         %ClusteredLevelGraph{g: %{g: g}},
         %Graph{} = t2,
         direction,
         constraints
       ) do
    edge_map = edge_transfer_map(g, t2, direction)

    t2
    |> ClusterTree.clusters()
    |> Enum.map(fn c -> {c, Map.get(edge_map, c, []), Map.get(constraints, c, Graph.new())} end)
    |> Enum.map(fn {c, edges, constraints} ->
      {c, crossing_reduction_graph(t2, c, v1s, edges, constraints)}
    end)
    |> Map.new()
  end

  @spec crossing_reduction_graph(Graph.t(), vertex, permutation, [edge], Graph.t()) ::
          CrossingReductionGraph.t()
  defp crossing_reduction_graph(t2, c, v1s, edges, constraints) do
    edges
    |> Enum.reduce(cluster_subgraph(t2, c, v1s), fn {v1, v2}, acc ->
      Graph.add_edge(acc, v1, v2)
    end)
    |> LevelGraph.new(fn g, v -> Graph.vertex(g, v, :r) end)
    |> CrossingReductionGraph.new(constraints)
  end

  @spec sorter(direction) :: (vertex, vertex -> boolean)
  defp sorter(:down), do: &<=/2
  defp sorter(:up), do: &>=/2

  @spec edge_transfer_map(Graph.t(), Graph.t(), direction) :: %{vertex: [vertex]}
  defp edge_transfer_map(%Graph{} = g, %Graph{} = t2, direction) do
    case Graph.source_vertices(t2) do
      [root] ->
        g
        |> Graph.get_edges(edge_fn(direction))
        |> Enum.flat_map(fn {w1, w2} -> transfer_edges(w1, w2, root, t2) end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    end
  end

  @spec transfer_edges(vertex, vertex, vertex, Graph.t()) :: [
          {vertex, {vertex, vertex}}
        ]
  defp transfer_edges(w1, w2, root, t2) do
    t2
    |> path_pairs(root, w2)
    |> Enum.map(fn [parent, child] -> {parent, {w1, child}} end)
  end

  @spec edge_fn(direction) :: ({any, {vertex, vertex, any}} -> edge)
  defp edge_fn(:down), do: fn {_, {w1, w2, _}} -> {w1, w2} end
  defp edge_fn(:up), do: fn {_, {w1, w2, _}} -> {w2, w1} end

  defp cluster_subgraph(%Graph{} = t2, c, v1s) do
    t2
    |> Graph.out_neighbours(c)
    |> Enum.map(&{&1, %{r: 2}})
    |> Enum.concat(v1s)
    |> Map.new()
    |> Graph.new()
  end

  defp path_pairs(t2, root, v2) do
    t2
    |> Graph.get_path(root, v2)
    |> Enum.chunk_every(2, 1, :discard)
  end

  @spec clustered_crossing_reduction(Graph.t(), Graph.t()) :: ClusteredLevelGraph.t()
  def clustered_crossing_reduction(%Graph{} = g, %Graph{} = t) do
    case Graph.source_vertices(t) do
      [root] ->
        g
        |> normalize(t)
        |> reduce_crossings(root)
    end
  end

  @spec clustered_crossing_reduction(ClusteredLevelGraph.t()) :: ClusteredLevelGraph.t()
  def clustered_crossing_reduction(%ClusteredLevelGraph{t: t} = clg) do
    case Graph.source_vertices(t) do
      [root] -> reduce_crossings(clg, root)
    end
  end

  @spec normalize(Graph.t(), Graph.t()) :: ClusteredLevelGraph.t()
  def normalize(%Graph{} = g, %Graph{} = t) do
    g
    |> NestingGraph.new(t)
    |> normalize()
  end

  @spec normalize(ClusteredLevelGraph.t()) :: ClusteredLevelGraph.t()
  def normalize(%ClusteredLevelGraph{} = clg) do
    clg
    |> ClusteredLevelGraph.split_long_edges()
    |> ClusteredLevelGraph.insert_border_segments()
    |> ClusteredLevelGraph.initialize_pos()
  end

  defp reduce_crossings(clg, root, direction \\ :down, prev_crossings \\ :infinity)

  defp reduce_crossings(%ClusteredLevelGraph{} = clg, _root, _dir, 0) do
    Logger.info("Final cross count 0")
    %{clg | crossings: 0}
  end

  defp reduce_crossings(%ClusteredLevelGraph{} = clg, root, _direction, :infinity) do
    case ClusteredLevelGraph.cross_count(clg) do
      m -> Logger.info("Initial cross count #{m}")
    end

    # [[:down, :up], [:up, :down]]
    [[:down, :up]]
    |> Enum.map(&Enum.reduce(&1, clg, fn dir, clg -> sweep(clg, root, dir) end))
    |> Enum.map(&{ClusteredLevelGraph.cross_count(&1), &1})
    |> case do
      [{c, clg}] ->
        reduce_crossings(clg, root, :down, c)

      [{c_min, clg}, {c_max, _}] when c_min < c_max ->
        Logger.info("Downward sweep first was best #{c_min} < #{c_max}")
        reduce_crossings(clg, root, :down, c_min)

      [{c_max, _}, {c_min, clg}] ->
        Logger.info("Upward sweep first was best #{c_min} < #{c_max}")
        reduce_crossings(clg, root, :up, c_min)
    end
  end

  defp reduce_crossings(%ClusteredLevelGraph{} = clg, root, direction, n) do
    Logger.info("Cross count #{n}")
    clg2 = sweep(clg, root, direction)

    case ClusteredLevelGraph.cross_count(clg2) do
      m when m < n ->
        reduce_crossings(clg2, root, reverse(direction), m)

      _ ->
        Logger.info("Final cross count #{n}")
        %{clg | crossings: n}
    end
  end

  defp reverse(:down), do: :up
  defp reverse(:up), do: :down

  def sweep(%ClusteredLevelGraph{} = clg, root, direction) do
    clg
    |> ClusteredLevelGraph.span(root)
    |> Tuple.to_list()
    |> Enum.sort_by(& &1, sorter(direction))
    |> to_range()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(clg, &sweep_levels(&2, &1, direction, root))
  end

  @spec sweep_levels(ClusteredLevelGraph.t(), [LevelGraph.level()], direction, vertex) ::
          ClusteredLevelGraph.t()
  defp sweep_levels(%ClusteredLevelGraph{} = clg, levels, direction, root) do
    clg
    |> ClusteredLevelGraph.subgraph(levels)
    |> crossing_reduction_graphs(direction)
    |> permute(root)
    |> Enum.with_index(1)
    |> Enum.reduce(clg, fn {v, b}, clg -> ClusteredLevelGraph.put_label(clg, v, %{b: b}) end)
  end

  defp to_range([first, last]), do: first..last
end
