defmodule Graph.RankAssignment.Split do
  @moduledoc """
  Support for splitting clusters that span multiple ranks but that don't have
  children on each rank of the span.
  """

  alias Graph.ClusterTree

  require Logger

  @spec split_clusters(Graph.t()) :: Graph.t()
  def split_clusters(%Graph{} = g) do
    g
    |> ClusterTree.post_order_clusters()
    |> Enum.reject(&(Graph.in_degree(g, &1) == 0))
    |> Enum.filter(&multispan?(g, &1))
    |> Enum.reduce(g, &split_cluster/2)
  end

  defp multispan?(%Graph{} = g, v) do
    case Graph.vertex(g, v, :r) do
      l when is_list(l) and length(l) > 1 -> true
      _ -> false
    end
  end

  defp split_cluster(w, %Graph{} = g) do
    with %{} = groups <- chunk_children(g, w),
         %Graph{} = acc <- Graph.del_vertex(g, w) do
      Enum.reduce(groups, acc, add_cluster_span_vertex(g, w))
    end
  end

  defp add_cluster_span_vertex(%Graph{} = g, w) do
    with [parent] <- Graph.in_neighbours(g, w),
         label <- Graph.vertex_label(g, w) do
      fn {r, vs}, %Graph{} = g ->
        Logger.debug("Splitting cluster #{inspect(w)} at span #{inspect(r)}")

        g =
          g
          |> Graph.add_vertex({w, r}, Map.put(label, :r, r))
          |> Graph.add_edge(parent, {w, r})

        Enum.reduce(vs, g, &Graph.add_edge(&2, {w, r}, &1))
      end
    end
  end

  defp chunk_children(%Graph{} = t, w) do
    case Graph.vertex(t, w, :r) do
      rs when is_list(rs) ->
        t
        |> Graph.out_neighbours(w)
        |> Enum.group_by(&containing_span(t, &1, rs))
    end
  end

  defp containing_span(%Graph{} = t, v, spans) do
    t
    |> Graph.vertex(v, :r)
    |> containing_span(spans)
  end

  defp containing_span(rank_or_span, spans) do
    Enum.find(spans, &contains?(&1, rank_or_span))
  end

  defp contains?(_.._//_ = r, [span]) do
    contains?(r, span)
  end

  defp contains?(_.._//_ = r, r1..r2//_) do
    Enum.all?([r1, r2], &contains?(r, &1))
  end

  defp contains?(_.._//_ = r, rank) do
    Enum.member?(r, rank)
  end
end
