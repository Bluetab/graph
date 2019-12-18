defmodule Graph.ConstrainedCrossingReduction do
  @moduledoc """
  Implementation of a heuristic for constrained two-level crossing reduction,
  based on the description in Michael Forster's paper:

  Forster M. (2005) A Fast and Simple Heuristic for Constrained Two-Level
  Crossing Reduction. In: Pach J. (eds) Graph Drawing. GD 2004. Lecture Notes in
  Computer Science, vol 3383. Springer, Berlin, Heidelberg,
  https://doi.org/10.1007/978-3-540-31843-9_22
  """

  alias Graph.ConstraintGraph
  alias Graph.Vertex

  require Logger

  @type graph :: Graph.t()
  @type label :: Vertex.label()
  @type vertex :: Vertex.id()
  @type vertices :: Enumerable.t()
  @type constraint :: {vertex, vertex}
  @type measure_fn :: (vertex -> number)

  @doc """
  For a given two-level graph G = (V1, V2, E) and acyclic constraint graph
  Gc ⊆ V2 x V2, returns a permutation of V2 satisfying the constraints and
  otherwise ordered by the measure function `b` (barycenter measure).
  """
  @spec permute(graph, graph, measure_fn) :: vertices
  def permute(%Graph{} = g, %Graph{} = gc, b) do
    v2 = Graph.in_vertices(g)

    g =
      Enum.reduce(v2, g, fn v, g ->
        case Graph.vertex(g, v) do
          nil ->
            raise(ArgumentError, "No vertex #{inspect(v)}")

          %Vertex{id: id, label: label} ->
            label =
              label
              |> Map.put(:l, [v])
              |> Map.put(:b, b.(id))
              |> Map.put(:d, Graph.in_degree(g, id))

            Graph.add_vertex(g, id, label)
        end
      end)

    v2
    |> unconstrained_vertices(gc)
    |> resolve_constraints(g, gc)
  end

  @spec unconstrained_vertices(vertices, graph) :: vertices
  defp unconstrained_vertices(vs, %Graph{} = gc) do
    vs
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(Graph.vertices(gc)))
  end

  @spec resolve_constraints(vertices, graph, graph) :: vertices
  defp resolve_constraints(vs, %Graph{} = g, %Graph{} = gc) do
    b = fn v -> Graph.vertex(g, v, :b) end

    gc
    |> ConstraintGraph.find_violated_constraint(b)
    |> resolve_constraint(vs, g, gc)
  end

  @spec resolve_constraint(constraint | nil, vertices, graph, graph) :: vertices
  defp resolve_constraint(constraint, vs, g, gc)

  defp resolve_constraint(nil = _constraint, vs, %Graph{} = g, %Graph{} = gc) do
    gc
    |> Graph.vertices()
    |> MapSet.new()
    |> MapSet.union(vs)
    |> Enum.sort_by(&Graph.vertex(g, &1, :b))
    |> Enum.map(&Graph.vertex(g, &1, :l))
    |> Enum.flat_map(& &1)
  end

  defp resolve_constraint({s, t} = _constraint, vs, %Graph{} = g, %Graph{} = gc) do
    vc = [s, t]
    Logger.debug("Detected violated constraint #{inspect(vc)}")

    g = Graph.add_vertex(g, vc, merge_labels(g, {s, t}))
    gc = ConstraintGraph.merge_constraints(gc, {s, t}, vc)

    vs =
      case Graph.degree(gc, vc) do
        0 -> MapSet.put(vs, vc)
        _ -> vs
      end

    resolve_constraints(vs, g, gc)
  end

  @spec merge_labels(graph, constraint) :: label
  defp merge_labels(%Graph{} = g, {s, t}) do
    [s, t]
    |> Enum.map(&Graph.vertex(g, &1))
    |> Enum.reduce(fn
      %Vertex{label: l2}, %Vertex{label: l1} ->
        d = l1.d + l2.d
        b = (l1.b * l1.d + l2.b * l2.d) / d
        l = l1.l ++ l2.l
        %{b: b, d: d, l: l}
    end)
  end
end
