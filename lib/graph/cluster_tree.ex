defmodule Graph.ClusterTree do
  alias Graph.Edge
  alias Graph.Vertex

  @doc """
  Returns the clusters of a tree (vertices with out degree > 0)
  """
  @spec clusters(Graph.t()) :: [Vertex.id()]
  def clusters(%Graph{out_edges: out_edges}) do
    Map.keys(out_edges)
  end

  @doc """
  Returns the leaves of a tree (vertices with out degree == 0)
  """
  @spec leaves(Graph.t()) :: [Vertex.id()]
  def leaves(%Graph{} = t) do
    Graph.sink_vertices(t)
  end

  @doc """
  Returns a contracted cluster tree by removing each single-childed
  cluster and connecting the child directly to the grandparent.
  """
  @spec contracted(Graph.t()) :: Graph.t()
  def contracted(%Graph{} = g) do
    do_contract(g)
  end

  defp do_contract(%Graph{} = g) do
    g
    |> Graph.vertices()
    |> Enum.filter(&(Graph.out_degree(g, &1) == 1))
    |> do_contract(g)
  end

  defp do_contract([], %Graph{} = g), do: g

  defp do_contract([v | _], %Graph{} = g) do
    g
    |> Graph.in_neighbours(v)
    |> do_contract(v, g)
    |> do_contract()
  end

  defp do_contract([], v, %Graph{} = g) do
    g
    |> Graph.del_vertex(v)
  end

  defp do_contract([parent], v, %Graph{} = g) do
    g
    |> Graph.out_edges(v)
    |> Enum.map(&Graph.edge(g, &1))
    |> Enum.reduce(g, fn %Edge{id: edge_id, v2: child, label: l}, g ->
      g
      |> Graph.del_edge(edge_id)
      |> Graph.add_edge(parent, child, l)
    end)
    |> Graph.del_vertex(v)
  end

  def depth(%Graph{} = t) do
    case Graph.source_vertices(t) do
      [root] -> do_depth(t, root, 0)
    end
  end

  defp do_depth(t, v, d) do
    case Graph.out_neighbours(t, v) do
      [] ->
        d

      vs ->
        vs
        |> Enum.map(&do_depth(t, &1, d + 1))
        |> Enum.max()
    end
  end
end
