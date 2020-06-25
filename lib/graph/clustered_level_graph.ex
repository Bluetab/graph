defmodule Graph.ClusteredLevelGraph do
  @moduledoc """
  A Clustered Level Graph is defined as a k-level graph $(V, E, C, I, Phi)$ and
  a cluster tree $Gamma = (V uu C, I), V nn C = O/$.
  """

  alias Graph.ClusterTree
  alias Graph.Edge
  alias Graph.EdgeRouting
  alias Graph.LevelGraph
  alias Graph.Traversal
  alias Graph.Vertex

  defstruct g: %LevelGraph{}, t: %Graph{}, crossings: 0

  @type t :: %__MODULE__{g: LevelGraph.t(), t: Graph.t()}
  @type span :: {pos_integer, pos_integer}

  @doc """
  Given a [k-level graph](`t:Graph.LevelGraph.t/0`) $(V, E, C, I, Phi)$ and a
  [cluster tree](`t:Graph.t/0`) $Gamma = (V uu C, I), V nn C = O/$, returns a
  new clustered level graph.
  """
  @spec new(LevelGraph.t(), Graph.t()) :: t
  def new(%LevelGraph{g: g} = lg, %Graph{} = t) do
    with v1s <- Graph.vertices(g),
         v2s <- Graph.sink_vertices(t),
         [] <- diff(v1s, v2s),
         true <- Graph.is_arborescence(t) do
      %__MODULE__{g: lg, t: t}
    else
      [_ | _] = vs -> raise(ArgumentError, "vertices must match (#{inspect(vs)}")
      false -> raise(ArgumentError, "second argument must be an arborescence")
    end
  end

  defp diff(v1s, v2s) do
    v1s = MapSet.new(v1s)
    v2s = MapSet.new(v2s)

    if v1s == v2s do
      []
    else
      v1s
      |> MapSet.difference(v2s)
      |> MapSet.union(MapSet.difference(v2s, v1s))
      |> MapSet.to_list()
    end
  end

  @doc """
  Returns a subgraph of a clustered k-level graph with vertices from the
  specified `levels`.
  """
  @spec subgraph(t, [pos_integer]) :: t
  def subgraph(%__MODULE__{g: lg, t: t}, levels) do
    case LevelGraph.subgraph(lg, levels) do
      %{g: g} = lg ->
        vs =
          g
          |> Graph.vertices()
          |> Traversal.reaching(t)

        new(lg, Graph.subgraph(t, vs))
    end
  end

  @doc """
  Returns the span ${Phi_min(c), Phi_max(c)}$ of a vertex `v`.
  """
  @spec new(t, Vertex.id()) :: span
  def span(%__MODULE__{} = clg, v) do
    clg
    |> levels(v)
    |> Enum.min_max()
  end

  @doc """
  A clustered k-level graph is proper if all edges are proper and each cluster
  $c in C$ contains a vertex on any spanned level: $forall i in Phi(c): V_c nn
  V_i != O/$
  """
  @spec is_proper?(t) :: boolean
  def is_proper?(%__MODULE__{g: g, t: t} = clg) do
    LevelGraph.is_proper?(g) and
      Enum.all?(ClusterTree.clusters(t), fn c ->
        clg
        |> levels(c)
        |> Enum.reduce_while(false, fn
          l, false -> {:cont, l}
          l, prev when l == prev + 1 -> {:cont, l}
          _, _ -> {:halt, false}
        end)
      end)
  end

  @spec levels(t, Vertex.id()) :: MapSet.t()
  def levels(%__MODULE__{g: g, t: t}, v) do
    [v]
    |> Traversal.reachable(t)
    |> Enum.filter(&(Graph.out_degree(t, &1) == 0))
    |> Enum.map(&LevelGraph.level(g, &1))
    |> MapSet.new()
  end

  @spec level_cluster_trees(t, Keyword.t()) :: %{pos_integer: Graph.t()}
  def level_cluster_trees(%__MODULE__{g: g, t: t}, opts \\ []) do
    t
    |> ClusterTree.leaves()
    |> Enum.group_by(&LevelGraph.level(g, &1))
    |> Enum.map(fn {level, vs} -> {level, Traversal.reaching_subgraph(t, vs)} end)
    |> contracted(Keyword.get(opts, :contracted, false))
    |> Map.new()
  end

  defp contracted(ts, false), do: ts

  defp contracted(ts, _truthy) do
    Enum.map(ts, fn {level, g} -> {level, ClusterTree.contracted(g)} end)
  end

  @doc """
  Returns a list of clusters spanning a given `min` and `max` level.
  """
  @spec clusters(t, {pos_integer, pos_integer}) :: [Vertex.id()]
  def clusters(%__MODULE__{t: t} = clg, {min, max}) do
    t
    |> ClusterTree.clusters()
    |> Enum.group_by(&span(clg, &1))
    |> Enum.filter(fn {{min1, max1}, _} -> min1 <= min and max1 >= max end)
    |> Enum.flat_map(fn {_span, cs} -> cs end)
  end

  @doc """
  Returns a list of vertices at a given level of the clustered k-level graph
  """
  @spec vertices_by_level(t, pos_integer) :: [Vertex.id()]
  def vertices_by_level(%__MODULE__{g: g}, level) do
    LevelGraph.vertices_by_level(g, level)
  end

  @spec vertices_by_span(t) :: %{span: [Vertex.id()]}
  def vertices_by_span(%__MODULE__{t: t} = clg) do
    t
    |> Graph.vertices()
    |> Enum.group_by(&span(clg, &1))
  end

  @spec insert_border_segments(t) :: t
  def insert_border_segments(%__MODULE__{t: t} = clg) do
    t
    |> ClusterTree.clusters()
    |> Enum.map(&{&1, span(clg, &1)})
    |> Enum.reduce(clg, &insert_border_segments/2)
  end

  @spec insert_border_segments({Vertex.id(), span}, t) :: t
  defp insert_border_segments({c, {min, max}}, %__MODULE__{} = clg) do
    clg =
      min..max
      |> Enum.reduce(clg, fn rank, %__MODULE__{g: %{g: g} = lg, t: t} = acc ->
        dummy = rank > min and rank < max

        t =
          t
          |> Graph.add_vertex({:l, c, rank})
          |> Graph.add_vertex({:r, c, rank})
          |> Graph.add_edge(c, {:l, c, rank})
          |> Graph.add_edge(c, {:r, c, rank})

        g =
          g
          |> Graph.add_vertex({:l, c, rank}, border: :left, r: rank, dummy: dummy)
          |> Graph.add_vertex({:r, c, rank}, border: :right, r: rank, dummy: dummy)

        lg = %{lg | g: g}

        %{acc | g: lg, t: t}
      end)

    clg =
      min..max
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(clg, fn [rank1, rank2], %__MODULE__{g: %{g: g} = lg} = acc ->
        inner = rank1 > min and rank2 < max

        g =
          g
          |> Graph.add_edge({:l, c, rank1}, {:l, c, rank2}, inner: inner)
          |> Graph.add_edge({:r, c, rank1}, {:r, c, rank2}, inner: inner)

        lg = %{lg | g: g}

        %{acc | g: lg}
      end)

    clg
  end

  def concentrate_dummy_edges(%__MODULE__{g: %{g: g} = lg} = clg) do
    {out_edges, in_edges} =
      g
      |> Graph.get_edges(fn {_, {v1, v2, _}} -> {v1, v2} end)
      |> Enum.filter(fn
        {v1, {v1, _, _} = v2} -> LevelGraph.level(lg, v2) == LevelGraph.level(lg, v1) + 1
        {{_, v2, _} = v1, v2} -> LevelGraph.level(lg, v2) == LevelGraph.level(lg, v1) + 1
        _ -> false
      end)
      |> Enum.split_with(fn
        {v1, {v1, _, _} = _v2} -> true
        _ -> false
      end)

    clg =
      out_edges
      |> Enum.map(&elem(&1, 1))
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.filter(fn {_v1, v2s} -> Enum.count(v2s) > 1 end)
      |> Enum.map(fn {_v1, [v2 | v2s]} -> {v2, v2s} end)
      |> Enum.reduce(clg, &concentrate_dummy_edge/2)

    in_edges
    |> Enum.map(&elem(&1, 0))
    |> Enum.group_by(&elem(&1, 1))
    |> Enum.filter(fn {_v2, v1s} -> Enum.count(v1s) > 1 end)
    |> Enum.map(fn {_v2, [v1 | v1s]} -> {v1, v1s} end)
    |> Enum.reduce(clg, &concentrate_dummy_edge/2)
  end

  defp concentrate_dummy_edge({v2, v2s}, %__MODULE__{g: %{g: g} = lg, t: t} = clg) do
    in_neighbours = Enum.flat_map(v2s, &Graph.in_neighbours(g, &1))
    out_neighbours = Enum.flat_map(v2s, &Graph.out_neighbours(g, &1))
    g = Graph.del_vertices(g, v2s)
    g = Enum.reduce(in_neighbours, g, &Graph.add_edge(&2, &1, v2))
    g = Enum.reduce(out_neighbours, g, &Graph.add_edge(&2, v2, &1))
    %{clg | g: %{lg | g: g}, t: Graph.del_vertices(t, v2s)}
  end

  @spec split_long_edges(t) :: t
  def split_long_edges(%__MODULE__{g: lg, t: t} = clg) do
    case Graph.source_vertices(t) do
      [root] ->
        lg
        |> LevelGraph.long_span_edges()
        |> Enum.reduce(clg, &split_long_edge(&2, &1, root))

        # |> concentrate_dummy_edges()
    end
  end

  @spec split_long_edge(t, Edge.t(), Vertex.id()) :: t
  defp split_long_edge(
         %__MODULE__{g: %{g: g} = lg, t: t} = clg,
         %Edge{id: edge_id, v1: v1, v2: v2, label: l} = e,
         root
       ) do
    routing = EdgeRouting.edge_routing(clg, e, root)

    {first, last} = Enum.min_max_by([v1, v2], &LevelGraph.level(lg, &1))

    # [l1, l2] = Enum.map([first, last], &LevelGraph.level(lg, &1))
    # validate(routing, l1, l2, first, last)

    {g, t} =
      routing
      |> Enum.sort()
      |> Enum.reduce({Graph.del_edge(g, edge_id), t, first}, fn {r, c}, {g, t, w_prev} ->
        w = {v1, v2, r}

        g =
          g
          |> Graph.add_vertex(w, r: r, dummy: true)
          |> Graph.add_edge(w_prev, w, l)

        t =
          t
          |> Graph.add_vertex(w)
          |> Graph.add_edge(c, w)

        {g, t, w}
      end)
      |> (fn {g, t, w_prev} -> {Graph.add_edge(g, w_prev, last, l), t} end).()

    lg = %{lg | g: g}
    %{clg | g: lg, t: t}
  end

  # can be used for debugging routing...
  def validate(%{} = routing, l1, l2, first, last) do
    case routing |> Map.keys() |> Enum.min_max() do
      {min, max} when min == l1 + 1 and max == l2 - 1 ->
        :ok

      {min, max} ->
        %{l1: l1, l2: l2, min: min, max: max, first: first, last: last, routing: routing}

        raise("Invalid routing")
    end
  end

  @doc """
  Initializes the position of each vertex in a clustered k-level graph by
  assigning a value to a given `label`. The assigned value will be unique within
  each level of the graph.
  """
  @spec initialize_pos(t, term) :: t
  def initialize_pos(%__MODULE__{g: lg} = clg, label \\ :b) do
    %{clg | g: LevelGraph.initialize_pos(lg, label)}
  end

  @doc """
  Associates `labels` with a vertex of a clustered level graph.
  """
  @spec put_label(t, Vertex.id(), Vertex.label()) :: t
  def put_label(%__MODULE__{g: lg} = clg, v, labels) do
    %{clg | g: LevelGraph.put_label(lg, v, labels)}
  end

  def cross_count(%__MODULE__{g: lg}) do
    LevelGraph.cross_count(lg)
  end

  defimpl Inspect do
    import Inspect.Algebra

    alias Graph.ClusteredLevelGraph

    def inspect(%ClusteredLevelGraph{} = clg, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      vs = ClusteredLevelGraph.vertices_by_span(clg)
      concat(["#ClusteredLevelGraph<", Inspect.Map.inspect(vs, opts), ">"])
    end
  end
end
