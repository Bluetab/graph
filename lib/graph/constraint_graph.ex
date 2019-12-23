defmodule Graph.ConstraintGraph do
  @moduledoc """
  Implementation of a constraing graph used in the heuristic for constrained
  two-level crossing reduction, based on the description in Michael Forster's
  paper:

  Forster M. (2005) A Fast and Simple Heuristic for Constrained Two-Level
  Crossing Reduction. In: Pach J. (eds) Graph Drawing. GD 2004. Lecture Notes in
  Computer Science, vol 3383. Springer, Berlin, Heidelberg,
  https://doi.org/10.1007/978-3-540-31843-9_22
  """

  alias Graph.Edge
  alias Graph.Vertex

  require Logger

  @type constraint :: {vertex, vertex}
  @type measure_fn :: (vertex -> number)
  @typep graph :: Graph.t()
  @typep vertex :: Vertex.id()

  @doc """
  Returns a new constraint graph with edges (w, v) representing an ordering
  constraint between vertices w and v.
  """
  @spec new([constraint]) :: graph
  def new(constraints) do
    Enum.reduce(constraints, Graph.new([], acyclic: true), &add_constraint/2)
  end

  @spec add_constraint({vertex, vertex}, graph) :: graph
  defp add_constraint({v1, v2}, %Graph{} = g), do: add_constraint([v1, v2], g)

  @spec add_constraint([vertex], graph) :: graph
  defp add_constraint([v1, v2], %Graph{} = g) do
    Logger.debug("Adding constraint [#{inspect(v1)}, #{inspect(v2)}]")

    g
    |> Graph.add_vertex(v1)
    |> Graph.add_vertex(v2)
    |> Graph.add_edge(v1, v2)
  end

  @doc """
  For a given constraint graph `gc` and a constraint c = (s, t), replaces
  constraints incident on `s` or `t` with new constraints incident on `vc`.
  """
  @spec merge_constraints(graph, constraint, vertex) :: graph
  def merge_constraints(%Graph{} = gc, {s, t}, vc) do
    Logger.debug("Merging constraints for #{inspect(s)}, #{inspect(t)}")

    gc
    |> Graph.edges()
    |> Enum.map(&Graph.edge(gc, &1))
    |> Enum.map(fn %Edge{v1: v1, v2: v2} -> [v1, v2] end)
    |> Enum.flat_map(& &1)
    |> Enum.map(&Map.get(%{s => vc, t => vc}, &1, &1))
    |> Enum.chunk_every(2)
    |> Enum.reject(&is_self_loop?(&1, vc))
    |> Enum.reduce(gc, &add_constraint/2)
    |> Graph.del_vertex(s)
    |> Graph.del_vertex(t)
    |> Graph.add_vertex(vc)
  end

  @spec is_self_loop?([vertex], vertex) :: boolean
  defp is_self_loop?([v, v], v), do: true
  defp is_self_loop?(_, _), do: false

  @doc """
  For a given constraint graph `cg` and measure function `b`, returns the first
  violated constraint (s, v) such that b(s) >= b(v), or nil if no constraints
  are violated. Constraints are traversed sorted lexicographically by the
  topsort number of the target and source vertices in ascending and descending
  order, respectively.
  """
  @spec find_violated_constraint(graph, measure_fn) :: nil | constraint
  def find_violated_constraint(%Graph{} = cg, b) do
    cg
    |> Graph.vertices()
    |> Enum.filter(&(Graph.in_degree(cg, &1) == 0))
    |> do_find_violated_constraint(cg, %{}, b)
  end

  @spec do_find_violated_constraint([Vertex.id()], graph, map, measure_fn) :: constraint | nil
  defp do_find_violated_constraint(vertices, cg, i, measure_fn)

  defp do_find_violated_constraint([], _, _, _), do: nil

  defp do_find_violated_constraint([v | vs], cg, %{} = i, b) do
    case do_find_violated_constraint(v, i, b) do
      {_s, _t} = c ->
        c

      nil ->
        {i, vs} =
          cg
          |> Graph.out_neighbours(v)
          |> Enum.reduce({i, vs}, &reduce_constraint(cg, v, &1, &2))

        do_find_violated_constraint(vs, cg, i, b)
    end
  end

  defp reduce_constraint(cg, v, t, {i, vs}) do
    l = [{v, t} | Map.get(i, t, [])]
    i = Map.put(i, t, l)

    vs =
      if Enum.count(l) == Graph.in_degree(cg, t) do
        [t | vs]
      else
        vs
      end

    {i, vs}
  end

  @spec do_find_violated_constraint(Vertex.id(), map, measure_fn) :: constraint | nil
  defp do_find_violated_constraint(v, %{} = i, b) do
    i
    |> Map.get(v, [])
    |> Enum.find(fn {s, v} -> b.(s) >= b.(v) end)
  end
end
