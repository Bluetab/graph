defmodule Bluetab.Graph.ClusteredGraph do
  @moduledoc """
  Forster (2005): A Clustered Bluetab.Graph $G = (V, E, C, I)$ consists of an underlying
  graph $(V, E)$, clusters $C$, and a recursive inclusion relation $I$. $I$
  builds a rooted tree $Gamma = (V uu C, I)$ with the clusters $C$ as inner
  nodes and the vertice $V$ as leaves, such that each cluster has at least two
  children. $Gamma$ is called the cluster tree of $G$.

  In this implementation we allow a cluster to have only one child.
  """
  alias Bluetab.Graph.Vertex

  defstruct g: %Bluetab.Graph{}, t: %Bluetab.Graph{}

  @type t :: %__MODULE__{g: Bluetab.Graph.t(), t: Bluetab.Graph.t()}

  @spec new(Bluetab.Graph.t(), Bluetab.Graph.t()) :: t
  def new(%Bluetab.Graph{} = g, %Bluetab.Graph{} = t) do
    if Bluetab.Graph.vertices(g) != Bluetab.Graph.sink_vertices(t) do
      raise(ArgumentError, "vertices must match")
    end

    unless Bluetab.Graph.tree?(t) do
      raise(ArgumentError, "second argument must be a tree")
    end

    %__MODULE__{g: g, t: t}
  end

  @spec subgraph(t, [Vertex.id()]) :: t
  def subgraph(%__MODULE__{g: g, t: t}, vs) do
    g = Bluetab.Graph.subgraph(g, vs)
    t = Bluetab.Graph.subgraph(t, vs)
    new(g, t)
  end
end
