defmodule Graph.CompoundGraph do
  alias Graph.Vertex

  defstruct g: %Graph{}, t: %Graph{}

  @type t :: %__MODULE__{g: Graph.t(), t: Graph.t()}

  @spec new(Graph.t(), Graph.t()) :: t
  def new(%Graph{} = g, %Graph{} = t) do
    if Graph.vertices(g) != Graph.vertices(t) do
      raise(ArgumentError, "vertices must match")
    end

    unless Graph.is_tree(t) do
      raise(ArgumentError, "second argument must be a tree")
    end

    %__MODULE__{g: g, t: t}
  end

  @spec subgraph(t, [Vertex.id()]) :: t
  def subgraph(%__MODULE__{g: g, t: t}, vs) do
    g = Graph.subgraph(g, vs)
    t = Graph.subgraph(t, vs)
    new(g, t)
  end
end
