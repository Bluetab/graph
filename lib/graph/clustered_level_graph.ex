defmodule Graph.ClusteredLevelGraph do
  alias Graph.ClusterTree
  alias Graph.LevelGraph
  alias Graph.Traversal
  alias Graph.Vertex

  defstruct g: %LevelGraph{}, t: %Graph{}

  @type t :: %__MODULE__{g: LevelGraph.t(), t: Graph.t()}

  @spec new(LevelGraph.t(), Graph.t()) :: t
  def new(%LevelGraph{g: g} = lg, %Graph{} = t) do
    leaves =
      t
      |> Graph.vertices()
      |> Enum.filter(&(Graph.out_degree(t, &1) == 0))

    if Graph.vertices(g) != leaves do
      raise(ArgumentError, "vertices must match")
    end

    unless Graph.is_tree(t) do
      raise(ArgumentError, "second argument must be a tree")
    end

    %__MODULE__{g: lg, t: t}
  end

  @spec new(t, Vertex.id()) :: {pos_integer, pos_integer}
  def span(%__MODULE__{} = clg, c) do
    clg
    |> levels(c)
    |> Enum.min_max()
  end

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
    |> Graph.vertices()
    |> Enum.filter(&(Graph.out_degree(t, &1) == 0))
    |> Enum.group_by(&LevelGraph.level(g, &1))
    |> Enum.map(fn {level, vs} -> {level, Traversal.reaching_subgraph(t, vs)} end)
    |> contracted(Keyword.get(opts, :contracted, false))
    |> Map.new()
  end

  defp contracted(ts, false), do: ts

  defp contracted(ts, _truthy) do
    Enum.map(ts, fn {level, g} -> {level, ClusterTree.contracted(g)} end)
  end

  def clusters(%__MODULE__{t: t} = clg, {min, max}) do
    t
    |> Graph.vertices()
    |> Enum.reject(&(Graph.out_degree(t, &1) == 0))
    |> Enum.group_by(&span(clg, &1))
    |> Enum.filter(fn {{min1, max1}, _} -> min1 <= min and max1 >= max end)
    |> Enum.flat_map(fn {_span, cs} -> cs end)
  end
end
