defmodule Graph.ClusteredCrossingReduction do
  alias Graph.ClusteredLevelGraph
  alias Graph.ConstrainedCrossingReduction
  alias Graph.CrossingReductionGraph
  alias Graph.Traversal
  alias Graph.Vertex

  require Logger

  # CLUSTERED CROSSING REDUCTION
  # - inputs:
  #   - A clustered two-level graph G = (V1 ∪ V2, E, C, I, Φ)
  #   - The contracted level cluster tree Δ₂
  # - output: A clustered level embedding of G
  #
  # r = root(g)
  # crossing-reduction-graph(r)
  # insert border edges
  # insert constraints for multi-level clusters
  # foreach c ∈ C do: minimize crossings in G'(c)
  # return an embedding π of V[2] by a DFS traversal of Δ₂

  @spec permute(ClusteredLevelGraph.t()) :: [Vertex.id()]
  def permute(%ClusteredLevelGraph{g: %{g: g}, t: t} = clg, fixed_level \\ 1, free_level \\ 2) do
    case Traversal.arborescence_root(t) do
      nil ->
        raise(ArgumentError, "cluster tree has no root")

      r ->
        crg = crossing_reduction_graph(clg, r, fixed_level, free_level)
        do_permute(g, crg)
    end
  end

  @spec do_permute(Graph.t(), CrossingReductionGraph.t()) :: [Vertex.id()]
  defp do_permute(%Graph{} = g, %CrossingReductionGraph{g: crg_x, gc: gc, sub: crg_ys} = crg) do
    b = barycenter_fn(crg.g)

    crg_x
    |> ConstrainedCrossingReduction.permute(gc, b)
    |> Enum.flat_map(fn v ->
      case Map.get(crg_ys, v) do
        nil -> [v]
        crg -> do_permute(g, crg)
      end
    end)
  end

  defp barycenter_fn(%Graph{} = g) do
    fn v ->
      case Graph.in_degree(g, v) do
        {:error, _} = e ->
          Logger.error("Missing vertex #{inspect(v)} #{inspect(Map.keys(g.vertices))}")
          e

        0 ->
          Logger.warn("Vertex #{inspect(v)} has in degree 0")
          1

        d ->
          b =
            g
            |> Graph.in_neighbours(v)
            |> Enum.map(&Graph.vertex(g, &1, :b))
            |> Enum.sum()

          b / d
      end
    end
  end

  def crossing_reduction_graph(
        %ClusteredLevelGraph{t: t} = clg,
        root,
        fixed_level \\ 1,
        free_level \\ 2
      ) do
    cs = ClusteredLevelGraph.clusters(clg, {fixed_level, free_level})

    constraints =
      cs
      |> Enum.group_by(&Graph.in_neighbours(t, &1))
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(&(Enum.count(&1) > 1))
      # |> TODO: ordering
      |> Enum.flat_map(&Enum.chunk_every(&1, 2, 1, :discard))
      |> Enum.map(fn [c1, c2] -> {c1, c2} end)

    clg
    |> CrossingReductionGraph.new(root, fixed_level, free_level)
    #|> CrossingReductionGraph.insert_border_edges(cs, fixed_level, 1)
    |> CrossingReductionGraph.insert_constraints(constraints)
  end
end
