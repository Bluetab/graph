defmodule Graph.ClusterTree do
  alias Graph.Edge
  alias Graph.Vertex

  @spec clusters(Graph.t()) :: [Vertex.id()]
  def clusters(%Graph{} = g) do
    g
    |> Graph.vertices()
    |> Enum.reject(&(Graph.out_degree(g, &1) == 0))
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
end
