defmodule Graph.EdgeRouting do
  @moduledoc """
  Edge routing for long-span edges, routing within the subgraphs nearest to the
  source and target vertices.
  """
  alias Graph.ClusteredLevelGraph
  alias Graph.Edge
  alias Graph.LevelGraph
  alias Graph.Vertex

  @type level :: LevelGraph.level()

  @spec edge_routing(ClusteredLevelGraph.t(), Edge.t(), Vertex.id()) ::
          %{level: Vertex.id()}
  def edge_routing(%ClusteredLevelGraph{} = clg, %Edge{v1: v1, v2: v2}, root) do
    edge_routing(clg, v1, v2, root)
  end

  @spec edge_routing(ClusteredLevelGraph.t(), Vertex.id(), Vertex.id(), Vertex.id()) ::
          %{level: Vertex.id()}
  def edge_routing(%ClusteredLevelGraph{g: lg} = clg, v1, v2, root) do
    [v1, v2]
    |> Enum.map(&{LevelGraph.level(lg, &1), &1})
    |> Enum.sort()
    |> case do
      [{l1, v1}, {l2, v2}] ->
        [v1, v2]
        |> Enum.map(&routing_map(clg, root, &1, l1 + 1, l2 - 1))
        |> Enum.reduce(&merge_routing_maps/2)
    end
  end

  defp merge_routing_maps(m1, m2) do
    m1
    |> Map.merge(m2, fn _k, v1, v2 -> Enum.min_by([v1, v2], fn {_, span} -> abs(span) end) end)
    |> Map.new(fn {k, {v, _}} -> {k, v} end)
  end

  defp routing_map(%ClusteredLevelGraph{g: lg, t: t}, root, v, l1, l2) do
    t
    |> Graph.get_short_path(root, v)
    |> Enum.reverse()
    |> tl()
    |> Enum.map(fn x ->
      l1 = max(l1, LevelGraph.level(lg, {x, :-}))
      l2 = min(l2, LevelGraph.level(lg, {x, :+}))
      {x, l1, l2}
    end)
    |> Enum.reject(fn {_, l1, l2} -> l2 < l1 end)
    |> Enum.flat_map(fn {x, l1, l2} -> Enum.map(l1..l2, &{&1, {x, l2 - l1}}) end)
    |> Enum.reduce(%{}, fn {l, v}, acc -> Map.put_new(acc, l, v) end)
  end
end
