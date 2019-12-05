defmodule Graph.CrossingReductionGraph do
  @moduledoc """
  Implementation of a crossing reduction graph, based on the description in
  Michael Forster's paper:

  Forster M. (2002) Applying Crossing Reduction Strategies to Layered Compound
  Graphs. In: Goodrich M.T., Kobourov S.G. (eds) Graph Drawing. GD 2002. Lecture
  Notes in Computer Science, vol 2528. Springer, Berlin, Heidelberg
  https://doi.org/10.1007/3-540-36151-0_26
  """
  alias Graph.ClusteredLevelGraph
  alias Graph.ConstraintGraph
  alias Graph.Edge
  alias Graph.Vertex

  defstruct g: %Graph{}, gc: %Graph{}, sub: %{}

  @type t :: %__MODULE__{g: Graph.t(), gc: Graph.t(), sub: %{vertex: t}}
  @type vertex :: Vertex.id()
  @type constraint :: {vertex, vertex}

  @doc """
  Returns a crossing reduction graph for the compound node `x` for a given
  `fixed_level` and `free_level` of a clustered two-level graph `clg`.
  """
  @spec new(ClusteredLevelGraph.t(), vertex, pos_integer, pos_integer) :: t
  def new(%ClusteredLevelGraph{g: g, t: t} = clg, x, fixed_level, free_level) do
    t2 =
      clg
      |> ClusteredLevelGraph.level_cluster_trees(contracted: false)
      |> Map.get(free_level)

    {vs, ys} =
      t
      |> Graph.out_neighbours(x)
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(Graph.vertices(t2)))
      |> Enum.split_with(&(Graph.out_degree(t, &1) == 0))

    v1s =
      clg
      |> ClusteredLevelGraph.vertices_by_level(fixed_level)
      |> Enum.map(&Graph.vertex(g.g, &1))
      |> Enum.map(fn %Vertex{id: id, label: label} -> {id, label} end)
      |> Map.new()

    edge_fn = edge_fn(g, fixed_level, free_level)

    crg =
      vs
      |> Enum.flat_map(&edge_fn.(&1))
      |> Enum.reduce(Graph.new(v1s, acyclic: true), fn
        %Edge{v1: v1, v2: v2}, acc ->
          acc
          |> Graph.add_vertex(v1)
          |> Graph.add_vertex(v2)
          |> Graph.add_edge(v1, v2, w: 1)
      end)

    subs =
      ys
      |> Enum.map(&{&1, new(clg, &1, fixed_level, free_level)})
      |> Map.new()

    crg = Enum.reduce(subs, crg, &inherit_edges/2)

    %__MODULE__{g: crg, sub: subs}
  end

  defp edge_fn(%Graph.LevelGraph{g: g}, fixed_level, free_level) when fixed_level < free_level do
    fn v ->
      g
      |> Graph.in_edges(v)
      |> Enum.map(&Graph.edge(g, &1))
    end
  end

  defp edge_fn(%Graph.LevelGraph{g: g}, fixed_level, free_level) when fixed_level > free_level do
    fn v ->
      g
      |> Graph.out_edges(v)
      |> Enum.map(&Graph.edge(g, &1))
      |> Enum.map(fn %Edge{v1: v1, v2: v2} = e -> %{e | v1: v2, v2: v1} end)
    end
  end

  @doc """
  Inserts vertices corresponding to the borders of the clusters `cs`, and
  edges with a given weight `w`.
  """
  @spec insert_border_edges(t, [vertex], number) :: t
  def insert_border_edges(crg, cs, w \\ 0.5)

  def insert_border_edges(%__MODULE__{} = crg, [], _w), do: crg

  def insert_border_edges(%__MODULE__{g: g, sub: sub} = crg, [c | cs], w) do
    if Graph.has_vertex?(g, c) do
      %{crg | g: do_insert_border_edges(g, c, w)}
    else
      sub =
        sub
        |> Enum.map(fn {y, crg_y} -> {y, insert_border_edges(crg_y, [c], w)} end)
        |> Map.new()

      %{crg | sub: sub}
    end
    |> insert_border_edges(cs, w)
  end

  @spec do_insert_border_edges(Graph.t(), vertex, number) :: Graph.t()
  defp do_insert_border_edges(%Graph{} = g, y, w) do
    g
    |> Graph.add_vertex({:l, y})
    |> Graph.add_vertex({:r, y})
    |> Graph.add_edge({:l, y}, y, w: w)
    |> Graph.add_edge({:r, y}, y, w: w)
  end

  @spec inherit_edges({vertex, t}, Graph.t()) :: t
  defp inherit_edges({y, %__MODULE__{g: gy}}, %Graph{} = g) do
    gy
    |> Graph.edges()
    |> Enum.map(&Graph.edge(gy, &1))
    |> Enum.reduce(g, &inherit_edge(&1, &2, y))
  end

  @spec inherit_edge(Edge.t(), Graph.t(), vertex) :: Graph.t()
  defp inherit_edge(%Edge{v1: u, v2: _v, label: %{w: _w1}}, %Graph{} = g, y) do
    g
    |> Graph.add_vertex(u)
    |> Graph.add_vertex(y)
    |> Graph.add_edge(u, y, w: 1)
  end

  @doc """
  Inserts constraints to be considered when generating embeddings (child orderings).
  """
  @spec insert_constraints(t, [constraint]) :: t
  def insert_constraints(crg, constraints)

  def insert_constraints(%__MODULE__{} = crg, []), do: crg

  def insert_constraints(%__MODULE__{sub: sub} = crg, [_ | _] = cs) do
    cs
    |> Enum.group_by(&count_members(sub, &1))
    |> Enum.reduce(crg, &do_insert_constraints/2)
  end

  @spec do_insert_constraints({2, [constraint]}, t) :: t
  defp do_insert_constraints({2, own_constraints}, %__MODULE__{} = crg) do
    %{crg | gc: ConstraintGraph.new(own_constraints)}
  end

  @spec do_insert_constraints({0, [constraint]}, t) :: t
  defp do_insert_constraints({0, sub_constraints}, %__MODULE__{sub: sub} = crg) do
    sub =
      sub
      |> Enum.map(fn {c, crg} -> {c, insert_constraints(crg, sub_constraints)} end)
      |> Map.new()

    %{crg | sub: sub}
  end

  @spec count_members(%{vertex: t}, constraint) :: 0 | 2
  defp count_members(%{} = sub, c) do
    sub
    |> Map.take(Tuple.to_list(c))
    |> Enum.count()
  end
end
