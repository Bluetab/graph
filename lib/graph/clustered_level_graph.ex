defmodule Graph.ClusteredLevelGraph do
  @moduledoc """
  A Clustered Level Graph is defined as a k-level graph $(V, E, C, I, Phi)$ and
  a cluster tree $Gamma = (V uu C, I), V nn C = O/$.
  """

  alias Graph.ClusterTree
  alias Graph.LevelGraph
  alias Graph.Traversal
  alias Graph.Vertex

  defstruct g: %LevelGraph{}, t: %Graph{}

  @type t :: %__MODULE__{g: LevelGraph.t(), t: Graph.t()}

  @doc """
  Given a [k-level graph](`t:Graph.LevelGraph.t/0`) $(V, E, C, I, Phi)$ and a
  [cluster tree](`t:Graph.t/0`) $Gamma = (V uu C, I), V nn C = O/$, returns a
  new clustered level graph.
  """
  @spec new(LevelGraph.t(), Graph.t()) :: t
  def new(%LevelGraph{g: g} = lg, %Graph{} = t) do
    if Graph.vertices(g) != Graph.sink_vertices(t) do
      raise(ArgumentError, "vertices must match")
    end

    unless Graph.is_tree(t) do
      raise(ArgumentError, "second argument must be a tree")
    end

    %__MODULE__{g: lg, t: t}
  end

  @doc """
  Returns the span ${Phi_min(c), Phi_max(c)}$ of a vertex `v`.
  """
  @spec new(t, Vertex.id()) :: {pos_integer, pos_integer}
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

  def insert_border_segments(%__MODULE__{t: t} = clg) do
    t
    |> ClusterTree.clusters()
    |> Enum.map(&{&1, span(clg, &1)})
    |> Enum.reduce(clg, &insert_border_segments/2)
  end

  defp insert_border_segments({c, {min, max}}, %__MODULE__{} = clg) do
    clg =
      min..max
      |> Enum.reduce(clg, fn rank, %__MODULE__{g: %{g: g} = lg, t: t} = acc ->
        t =
          t
          |> Graph.add_vertex({:l, c, rank})
          |> Graph.add_vertex({:r, c, rank})
          |> Graph.add_edge(c, {:l, c, rank})
          |> Graph.add_edge(c, {:r, c, rank})

        g =
          g
          |> Graph.add_vertex({:l, c, rank}, border: :left)
          |> Graph.add_vertex({:r, c, rank}, border: :right)

        lg = %{lg | g: g}

        %{acc | g: lg, t: t}
      end)

    clg =
      min..max
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(clg, fn [rank1, rank2], %__MODULE__{g: %{g: g} = lg} = acc ->
        g =
          g
          |> Graph.add_edge({:l, c, rank1}, {:l, c, rank2})
          |> Graph.add_edge({:r, c, rank1}, {:r, c, rank2})

        lg = %{lg | g: g}

        %{acc | g: lg}
      end)

    clg
  end
end
