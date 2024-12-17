defmodule Graph.ClusteredGraph do
  @moduledoc """
  Forster (2005): A Clustered Graph $G = (V, E, C, I)$ consists of an underlying
  graph $(V, E)$, clusters $C$, and a recursive inclusion relation $I$. $I$
  builds a rooted tree $Gamma = (V uu C, I)$ with the clusters $C$ as inner
  nodes and the vertice $V$ as leaves, such that each cluster has at least two
  children. $Gamma$ is called the cluster tree of $G$.

  In this implementation we allow a cluster to have only one child.
  """
  alias Graph.Vertex

  defstruct g: %Graph{}, t: %Graph{}

  @type t :: %__MODULE__{g: Graph.t(), t: Graph.t()}

  @spec new(Graph.t(), Graph.t()) :: t
  def new(%Graph{} = g, %Graph{} = t) do
    if Graph.vertices(g) != Graph.sink_vertices(t) do
      raise(ArgumentError, "vertices must match")
    end

    unless Graph.tree?(t) do
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
