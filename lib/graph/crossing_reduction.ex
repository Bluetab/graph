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

  @type vertex_id :: Graph.Vertex.id()
  @type direction :: :down | :up

  @spec crossing_reduction_graphs(ClusteredLevelGraph.t, direction) :: %{vertex_id: CrossingReductionGraph.t()}
  def crossing_reduction_graphs(%ClusteredLevelGraph{g: %{g: g}} = clg, direction \\ :down) do
    [{_, t1}, {_, t2}] =
      clg
      |> ClusteredLevelGraph.level_cluster_trees(contracted: false)
      |> Enum.sort_by(&elem(&1, 0), sorter(direction))

    constraints = constraints(clg, t1)

    t1
    |> ClusterTree.leaves()
    |> Enum.map(&{&1, %{b: Graph.vertex(g, &1, :b), r: 1}})
    |> crossing_reduction_graphs(clg, t2, direction, constraints)
  end

  def permute(%{} = crgs, root) do
    do_permute(crgs, root)
  end

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

  defp reorder_border_nodes(els, w) do
    Enum.sort_by(els, fn
      {:l, ^w, _} -> 0
      {:r, ^w, _} -> 2
      _ -> 1
    end)
  end

  defp constraints(%ClusteredLevelGraph{g: %{g: g}, t: t} = clg, %Graph{} = t1) do
    t
    |> ClusterTree.clusters()
    |> Enum.group_by(&ClusteredLevelGraph.levels(clg, &1))
    |> Enum.filter(fn {span, _} -> MapSet.size(span) > 1 end)
    |> Enum.flat_map(fn {_, cs} -> cs end)
    |> Enum.group_by(&Graph.in_neighbours(t, &1))
    |> Enum.reject(fn {parents, _} -> parents == [] end)
    |> Enum.reject(fn {_, children} -> Enum.count(children) < 2 end)
    |> Enum.map(fn {[parent], children} -> {parent, children} end)
    |> Map.new(fn {parent, children} -> {parent, constraint_graph(children, t1, g)} end)
  end

  defp constraint_graph(cs, %Graph{} = t1, %Graph{} = g) do
    cs
    |> Enum.sort_by(&order(t1, g, &1))
    |> Enum.chunk_every(2, 1, :discard)
    |> ConstraintGraph.new()
  end

  defp order(%Graph{} = t1, %Graph{} = g, c) do
    Graph.Traversal.reachable([c], t1)
    |> Enum.filter(&(Graph.out_degree(t1, &1) == 0))
    |> Enum.map(&Graph.vertex_label(g, &1))
    |> Enum.map(&Map.get(&1, :b))
    |> Enum.reduce({0, 0}, fn b, {sum, count} -> {sum + b, count + 1} end)
    |> (fn {sum, count} -> sum / count end).()
  end

  defp crossing_reduction_graphs(
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

  defp crossing_reduction_graph(t2, c, v1s, edges, constraints) do
    edges
    |> Enum.reduce(cluster_subgraph(t2, c, v1s), fn {v1, v2}, acc ->
      Graph.add_edge(acc, v1, v2)
    end)
    |> LevelGraph.new(fn g, v -> Graph.vertex(g, v, :r) end)
    |> CrossingReductionGraph.new(constraints)
  end

  defp sorter(:down), do: &<=/2
  defp sorter(:up), do: &>=/2

  defp edge_transfer_map(%Graph{} = g, %Graph{} = t2, direction) do
    case Graph.source_vertices(t2) do
      [root] ->
        g
        |> Graph.get_edges(edge_fn(direction))
        |> Enum.flat_map(fn {w1, w2} -> transfer_edges(w1, w2, root, t2) end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    end
  end

  defp transfer_edges(w1, w2, root, t2) do
    t2
    |> path_pairs(root, w2)
    |> Enum.map(fn [parent, child] -> {parent, {w1, child}} end)
  end

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
end
