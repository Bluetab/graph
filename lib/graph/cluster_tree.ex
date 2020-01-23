defmodule Graph.ClusterTree do
  @moduledoc """
  This module defines functions for operation on cluster trees.
  """

  alias Graph.Edge
  alias Graph.Traversal
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

  @spec do_contract(Graph.t()) :: Graph.t()
  defp do_contract(%Graph{} = g) do
    g
    |> Graph.vertices()
    |> Enum.filter(&(Graph.out_degree(g, &1) == 1))
    |> do_contract(g)
  end

  @spec do_contract([Vertex.id()], Graph.t()) :: Graph.t()
  defp do_contract([], %Graph{} = g), do: g

  defp do_contract([v | _], %Graph{} = g) do
    g
    |> Graph.in_neighbours(v)
    |> do_contract(v, g)
    |> do_contract()
  end

  @spec do_contract([Vertex.id()], Vertex.id(), Graph.t()) :: Graph.t()
  defp do_contract([], v, %Graph{} = g) do
    Graph.del_vertex(g, v)
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

  @spec depth(Graph.t()) :: non_neg_integer
  def depth(%Graph{} = t) do
    case Graph.source_vertices(t) do
      [root] -> do_depth(t, root, 0)
    end
  end

  @spec do_depth(Graph.t(), Vertex.id(), non_neg_integer) :: non_neg_integer
  defp do_depth(%Graph{} = t, v, d) do
    case Graph.out_neighbours(t, v) do
      [] ->
        d

      vs ->
        vs
        |> Enum.map(&do_depth(t, &1, d + 1))
        |> Enum.max()
    end
  end

  @spec height(Graph.t()) :: non_neg_integer
  def height(%Graph{} = t) do
    case Graph.source_vertices(t) do
      [root] -> height(t, root)
    end
  end

  @spec height(Graph.t(), Vertex.id()) :: non_neg_integer
  def height(%Graph{} = t, v) do
    case Graph.out_neighbours(t, v) do
      [] ->
        0

      vs ->
        vs
        |> Enum.map(&height(t, &1))
        |> Enum.max()
        |> Kernel.+(1)
    end
  end

  @spec post_order_clusters(Graph.t()) :: [Vertex.id()]
  def post_order_clusters(%Graph{} = t) do
    t
    |> Traversal.post_order()
    |> Enum.reject(&(Graph.out_degree(t, &1) == 0))
  end
end
