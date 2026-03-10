defmodule Bluetab.Graph.ClusterTree do
  @moduledoc """
  This module defines functions for operation on cluster trees.
  """

  alias Bluetab.Graph.Edge
  alias Bluetab.Graph.Traversal
  alias Bluetab.Graph.Vertex

  @doc """
  Returns the clusters of a tree (vertices with out degree > 0)
  """
  @spec clusters(Bluetab.Graph.t()) :: [Vertex.id()]
  def clusters(%Bluetab.Graph{out_edges: out_edges}) do
    Map.keys(out_edges)
  end

  @doc """
  Returns the leaves of a tree (vertices with out degree == 0)
  """
  @spec leaves(Bluetab.Graph.t()) :: [Vertex.id()]
  def leaves(%Bluetab.Graph{} = t) do
    Bluetab.Graph.sink_vertices(t)
  end

  @doc """
  Returns a contracted cluster tree by removing each single-childed
  cluster and connecting the child directly to the grandparent.
  """
  @spec contracted(Bluetab.Graph.t()) :: Bluetab.Graph.t()
  def contracted(%Bluetab.Graph{} = g) do
    do_contract(g)
  end

  @spec do_contract(Bluetab.Graph.t()) :: Bluetab.Graph.t()
  defp do_contract(%Bluetab.Graph{} = g) do
    g
    |> Bluetab.Graph.vertices()
    |> Enum.filter(&(Bluetab.Graph.out_degree(g, &1) == 1))
    |> do_contract(g)
  end

  @spec do_contract([Vertex.id()], Bluetab.Graph.t()) :: Bluetab.Graph.t()
  defp do_contract([], %Bluetab.Graph{} = g), do: g

  defp do_contract([v | _], %Bluetab.Graph{} = g) do
    g
    |> Bluetab.Graph.in_neighbours(v)
    |> do_contract(v, g)
    |> do_contract()
  end

  @spec do_contract([Vertex.id()], Vertex.id(), Bluetab.Graph.t()) :: Bluetab.Graph.t()
  defp do_contract([], v, %Bluetab.Graph{} = g) do
    Bluetab.Graph.del_vertex(g, v)
  end

  defp do_contract([parent], v, %Bluetab.Graph{} = g) do
    g
    |> Bluetab.Graph.out_edges(v)
    |> Enum.map(&Bluetab.Graph.edge(g, &1))
    |> Enum.reduce(g, fn %Edge{id: edge_id, v2: child, label: l}, g ->
      g
      |> Bluetab.Graph.del_edge(edge_id)
      |> Bluetab.Graph.add_edge(parent, child, l)
    end)
    |> Bluetab.Graph.del_vertex(v)
  end

  @spec depth(Bluetab.Graph.t()) :: non_neg_integer
  def depth(%Bluetab.Graph{} = t) do
    case Bluetab.Graph.source_vertices(t) do
      [root] -> do_depth(t, root, 0)
    end
  end

  @spec do_depth(Bluetab.Graph.t(), Vertex.id(), non_neg_integer) :: non_neg_integer
  defp do_depth(%Bluetab.Graph{} = t, v, d) do
    case Bluetab.Graph.out_neighbours(t, v) do
      [] ->
        d

      vs ->
        vs
        |> Enum.map(&do_depth(t, &1, d + 1))
        |> Enum.max()
    end
  end

  @spec height(Bluetab.Graph.t()) :: non_neg_integer
  def height(%Bluetab.Graph{} = t) do
    case Bluetab.Graph.source_vertices(t) do
      [root] -> height(t, root)
    end
  end

  @spec height(Bluetab.Graph.t(), Vertex.id()) :: non_neg_integer
  def height(%Bluetab.Graph{} = t, v) do
    case Bluetab.Graph.out_neighbours(t, v) do
      [] ->
        0

      vs ->
        vs
        |> Enum.map(&height(t, &1))
        |> Enum.max()
        |> Kernel.+(1)
    end
  end

  @spec post_order_clusters(Bluetab.Graph.t()) :: [Vertex.id()]
  def post_order_clusters(%Bluetab.Graph{} = t) do
    t
    |> Traversal.post_order()
    |> Enum.reject(&(Bluetab.Graph.out_degree(t, &1) == 0))
  end
end
