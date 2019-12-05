defmodule Graph.CrossCount do
  @moduledoc """
  Functions for counting edge crossings in graphs.
  """
  alias Graph.Vertex

  @doc """
  Returns the cross count of edges a bilayer graph. It is assumed that the graph
  is a proper 2-level graph, such that every edge emanates from a vertex in the
  first layer incides on a vertex in the second layer.

  If specified, the function `pos_fn` taking a vertex id and returning a term
  will be used used to determine the position of a vertex within its layer.
  Otherwise, the vertex label will be used.

    ## Examples

      iex> g = Graph.new(foo: [p: 1], bar: [p: 2], baz: [p: 1], xyzzy: [p: 2])
      iex> g = Graph.add_edges(g, foo: :xyzzy, bar: :baz)
      iex> CrossCount.bilayer_cross_count(g)
      1

  """
  @spec bilayer_cross_count(Graph.t(), nil | (Vertex.t() -> term())) :: non_neg_integer()
  def bilayer_cross_count(graph, pos_fn \\ nil)

  def bilayer_cross_count(%Graph{} = g, nil) do
    bilayer_cross_count(g, &Graph.vertex_label(g, &1))
  end

  def bilayer_cross_count(%Graph{} = g, pos_fn) when is_function(pos_fn) do
    g
    |> Graph.get_edges()
    |> Enum.map(fn %{v1: v1, v2: v2} -> {pos_fn.(v1), pos_fn.(v2)} end)
    |> Enum.sort()
    |> Enum.map(fn {_, v2} -> v2 end)
    |> sort_and_count()
    |> elem(1)
  end

  @doc """
  Merge-sort a list and count inversions.

    ## Examples

      iex> CrossCount.sort_and_count([1, 4, 3, 2, 2, 5])
      {[1, 2, 2, 3, 4, 5], 5}

  """
  @spec sort_and_count(Enumerable.t()) :: {Enumerable.t(), non_neg_integer()}
  def sort_and_count(l)

  def sort_and_count([]), do: {[], 0}
  def sort_and_count([_] = elems), do: {elems, 0}

  def sort_and_count([_ | _] = elems) do
    half =
      elems
      |> Enum.count()
      |> div(2)

    [{xs, x_count}, {ys, y_count}] =
      elems
      |> Enum.split(half)
      |> Tuple.to_list()
      |> Enum.map(&sort_and_count/1)

    {merged, m_count} = merge_and_count(xs, ys, half)
    {merged, x_count + y_count + m_count}
  end

  def sort_and_count(enumerable) when not is_list(enumerable) do
    enumerable
    |> Enum.to_list()
    |> sort_and_count()
  end

  @spec merge_and_count([term()], [term()], non_neg_integer()) :: {[term()], non_neg_integer()}
  defp merge_and_count(xs, ys, n) do
    do_merge_and_count(xs, ys, n)
  end

  @spec do_merge_and_count([term()], [term()], non_neg_integer()) :: {[term()], non_neg_integer()}
  defp do_merge_and_count(xs, ys, n)

  defp do_merge_and_count([], ys, _), do: {ys, 0}
  defp do_merge_and_count(xs, [], _), do: {xs, 0}

  defp do_merge_and_count([x | xs], [y | ys], n) when x <= y do
    {m, i} = do_merge_and_count(xs, [y | ys], n - 1)
    {[x | m], i}
  end

  defp do_merge_and_count(xs, [y | ys], n) do
    {m, i} = do_merge_and_count(xs, ys, n)
    {[y | m], i + n}
  end
end
