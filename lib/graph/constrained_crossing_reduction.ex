defmodule Bluetab.Graph.ConstrainedCrossingReduction do
  @moduledoc """
  Implementation of a heuristic for constrained two-level crossing reduction,
  based on the description in Michael Forster's paper:

  Forster M. (2005) A Fast and Simple Heuristic for Constrained Two-Level
  Crossing Reduction. In: Pach J. (eds) Bluetab.Graph Drawing. GD 2004. Lecture Notes in
  Computer Science, vol 3383. Springer, Berlin, Heidelberg,
  https://doi.org/10.1007/978-3-540-31843-9_22
  """

  alias Bluetab.Graph.Barycentre
  alias Bluetab.Graph.ConstraintGraph
  alias Bluetab.Graph.LevelGraph
  alias Bluetab.Graph.Vertex

  require Logger

  @type graph :: Bluetab.Graph.t()
  @type label :: Vertex.label()
  @type vertex :: Vertex.id()
  @type vertices :: Enumerable.t()
  @type constraint :: {vertex, vertex}
  @type measure_fn :: (vertex -> number)

  @doc """
  For a given two-level graph G = (V1, V2, E) and acyclic constraint graph
  Gc ⊆ V2 x V2, returns a permutation of V2 satisfying the constraints and
  otherwise ordered by the measure function `b` (barycentre measure).
  """
  @spec permute(LevelGraph.t(), graph, pos_integer) :: vertices
  def permute(%LevelGraph{g: g} = lg, %Bluetab.Graph{} = gc, level) do
    b = Barycentre.b(g)
    v2 = LevelGraph.vertices_by_level(lg, level)

    g =
      Enum.reduce(v2, g, fn v, g ->
        case Bluetab.Graph.vertex(g, v) do
          nil ->
            raise(ArgumentError, "No vertex #{inspect(v)}")

          %Vertex{id: id, label: label} ->
            label =
              label
              |> Map.put(:l, [v])
              |> Map.put(:b, b.(id))
              |> Map.put(:d, Bluetab.Graph.in_degree(g, id))

            Bluetab.Graph.add_vertex(g, id, label)
        end
      end)

    v2
    |> unconstrained_vertices(gc)
    |> resolve_constraints(g, gc)
  end

  @spec unconstrained_vertices(vertices, graph) :: vertices
  defp unconstrained_vertices(vs, %Bluetab.Graph{} = gc) do
    vs
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(Bluetab.Graph.vertices(gc)))
  end

  @spec resolve_constraints(vertices, graph, graph) :: vertices
  defp resolve_constraints(vs, %Bluetab.Graph{} = g, %Bluetab.Graph{} = gc) do
    b = fn v -> Bluetab.Graph.vertex(g, v, :b) end

    gc
    |> ConstraintGraph.find_violated_constraint(b)
    |> resolve_constraint(vs, g, gc)
  end

  @spec resolve_constraint(constraint | nil, vertices, graph, graph) :: vertices
  defp resolve_constraint(constraint, vs, g, gc)

  defp resolve_constraint(nil = _constraint, vs, %Bluetab.Graph{} = g, %Bluetab.Graph{} = gc) do
    gc
    |> Bluetab.Graph.vertices()
    |> MapSet.new()
    |> MapSet.union(vs)
    |> Enum.sort_by(&Bluetab.Graph.vertex(g, &1, :b))
    |> Enum.map(&Bluetab.Graph.vertex(g, &1, :l))
    |> Enum.flat_map(& &1)
  end

  defp resolve_constraint({s, t} = _constraint, vs, %Bluetab.Graph{} = g, %Bluetab.Graph{} = gc) do
    vc = [s, t]
    Logger.debug("Detected violated constraint #{inspect(vc)}")

    g = Bluetab.Graph.add_vertex(g, vc, merge_labels(g, {s, t}))
    gc = ConstraintGraph.merge_constraints(gc, {s, t}, vc)

    vs =
      case Bluetab.Graph.degree(gc, vc) do
        0 -> MapSet.put(vs, vc)
        _ -> vs
      end

    resolve_constraints(vs, g, gc)
  end

  @spec merge_labels(graph, constraint) :: label
  defp merge_labels(%Bluetab.Graph{} = g, {s, t}) do
    [s, t]
    |> Enum.map(&Bluetab.Graph.vertex(g, &1))
    |> Enum.reduce(fn
      %Vertex{label: l2}, %Vertex{label: l1} ->
        d = l1.d + l2.d
        b = (l1.b * l1.d + l2.b * l2.d) / d
        l = l1.l ++ l2.l
        %{b: b, d: d, l: l}
    end)
  end
end
