defmodule Graph.NestingGraph do
  @moduledoc """
  Sander (1996): The **nesting graph** of a compound graph $(G^', T^')$ consists
  of:
   1. the set of nodes $B uu {u^((-)) | u in S} uu {u^((+)) | u in S}$,
   2. an edge $(u^((-)), v)$ for each $(u, v) in E_T$ with $u in S$, $v in B$,
   3. an edge $(u_1^((-)), u_2^((-)))$ for each $(u_1, u_2) in E_T$ with $u_1,
      u_2 in S$,
   4. an edge $(v, u^((+)))$ for each $(u, v) in E_T$ with $u in S$, $v in B$,
   5. an edge $(u_2^((+)), u_1^((+)))$ for each $(u_1, u_2) in E_T$ with $u_1,
      u_2 in S$. We call the edges of the nesting graph **nesting edges**.
  """

  alias Graph.ClusteredLevelGraph
  alias Graph.ClusterTree
  alias Graph.LevelGraph
  alias Graph.Vertex

  defstruct g: %Graph{opts: [acyclic: true]}, t: %Graph{opts: [acyclic: true]}, cycles: []

  @type t :: %__MODULE__{g: Graph.t(), t: Graph.t(), cycles: [{Vertex.id(), Vertex.id()}]}

  @spec new(Graph.t(), Graph.t()) :: ClusteredLevelGraph.t()
  def new(%Graph{} = g, %Graph{} = t) do
    {ng, cycles} =
      t
      |> nodes()
      |> Graph.new(acyclic: true)
      |> add_nesting_edges(t)
      |> add_connectivity_edges(g, t)

    t =
      t
      |> ClusterTree.clusters()
      |> Enum.reduce(t, fn v, acc ->
        acc
        |> Graph.add_vertex({v, :-})
        |> Graph.add_vertex({v, :+})
        |> Graph.add_edge(v, {v, :-})
        |> Graph.add_edge(v, {v, :+})
      end)

    %__MODULE__{g: ng, t: t, cycles: cycles}
    |> rank_assignment()
    |> delete_nesting_edges()
    |> insert_cyclic_edges(cycles)
    |> LevelGraph.new(fn g, v -> rank(g, v) end)
    |> ClusteredLevelGraph.new(t)
  end

  @spec add_nesting_edges(Graph.t(), Graph.t()) :: Graph.t()
  defp add_nesting_edges(%Graph{} = ng, %Graph{} = t) do
    t
    |> Graph.get_edges()
    |> Enum.reduce(ng, fn %{v1: v1, v2: v2}, acc ->
      if Graph.has_vertex?(ng, v2) do
        acc
        |> Graph.add_edge({v1, :-}, v2, nesting: true)
        |> Graph.add_edge(v2, {v1, :+}, nesting: true)
      else
        acc
        |> Graph.add_edge({v1, :-}, {v2, :-}, nesting: true)
        |> Graph.add_edge({v2, :+}, {v1, :+}, nesting: true)
      end
    end)
  end

  @spec add_connectivity_edges(Graph.t(), Graph.t(), Graph.t()) ::
          {Graph.t(), [{Vertex.id(), Vertex.id()}]}
  def add_connectivity_edges(%Graph{} = ng, %Graph{} = g, %Graph{} = t) do
    is_leaf? = &MapSet.member?(leaves_set(t), &1)

    g
    |> Graph.get_edges()
    |> Enum.map(fn %{v1: v1, v2: v2} -> {v1, v2, is_leaf?.(v1), is_leaf?.(v2)} end)
    |> Enum.map(fn {v1, v2, v1_is_leaf, v2_is_leaf} ->
      cond do
        v1_is_leaf and v2_is_leaf -> {1, v1, v2}
        v2_is_leaf and Graph.get_path(t, v1, v2) -> {2, {v1, :-}, v2}
        v2_is_leaf -> {3, {v1, :+}, v2}
        v1_is_leaf and Graph.get_path(t, v2, v1) -> {4, v1, {v2, :+}}
        v1_is_leaf -> {5, v1, {v2, :-}}
        Graph.get_path(t, v1, v2) -> {6, {v1, :-}, {v2, :-}}
        Graph.get_path(t, v2, v1) -> {7, {v1, :+}, {v2, :+}}
        true -> {8, {v1, :+}, {v2, :-}}
      end
    end)
    |> Enum.sort()
    |> Enum.reduce({ng, []}, &add_edge/2)
  end

  @spec add_edge(
          {pos_integer, Vertex.id(), Vertex.id()},
          {Graph.t(), [{Vertex.id(), Vertex.id()}]}
        ) :: {Graph.t(), [{Vertex.id(), Vertex.id()}]}
  defp add_edge({_, v1, v2}, {%Graph{} = g, cycles}) do
    case Graph.add_edge(g, v1, v2) do
      %Graph{} = g ->
        {g, cycles}

      {:error, {:bad_edge, _path}} ->
        {g, [{v1, v2} | cycles]}
    end
  end

  @spec nodes(Graph.t()) :: [Vertex.id()]
  defp nodes(%Graph{} = t) do
    t
    |> ClusterTree.clusters()
    |> Enum.flat_map(fn v -> [{v, :-}, {v, :+}] end)
    |> Enum.concat(ClusterTree.leaves(t))
  end

  @spec rank_assignment(t) :: Graph.t()
  def rank_assignment(%__MODULE__{g: g, t: t}) do
    k = ClusterTree.depth(t)
    vs = Graph.Traversal.topsort(g)

    g =
      vs
      |> do_rank_assignment(g, 2 * k + 1)
      |> adjust_upper_borders(Enum.reverse(vs))

    vs
    |> Enum.group_by(&rank(g, &1))
    |> Map.values()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {vs, r} -> Enum.map(vs, &{&1, r}) end)
    |> Enum.reduce(g, fn {v, r}, acc -> Graph.put_label(acc, v, r: r) end)
  end

  @spec adjust_upper_borders(Graph.t(), [Vertex.id()]) :: Graph.t()
  defp adjust_upper_borders(g, vs)
  defp adjust_upper_borders(%Graph{} = g, []), do: g

  defp adjust_upper_borders(%Graph{} = g, [{_, :-} = v | vs]) do
    g
    |> Graph.put_label(v, r: min_succ_rank(v, g) - 1)
    |> adjust_upper_borders(vs)
  end

  defp adjust_upper_borders(%Graph{} = g, [_ | vs]) do
    adjust_upper_borders(g, vs)
  end

  @spec rank(Graph.t(), Vertex.id()) :: pos_integer
  defp rank(g, v) do
    g
    |> Graph.vertex_label(v)
    |> Map.get(:r)
  end

  @spec delete_nesting_edges(Graph.t()) :: Graph.t()
  defp delete_nesting_edges(%Graph{} = g) do
    g
    |> Graph.get_edges()
    |> Enum.filter(fn %{label: l} -> Map.get(l, :nesting) end)
    |> Enum.reduce(g, fn %{id: edge_id}, acc -> Graph.del_edge(acc, edge_id) end)
  end

  @spec insert_cyclic_edges(Graph.t(), [{Vertex.id(), Vertex.id()}]) :: Graph.t()
  defp insert_cyclic_edges(g, edges)

  defp insert_cyclic_edges(%Graph{} = g, []), do: g

  defp insert_cyclic_edges(%Graph{} = g, [{v1, v2} | es]) do
    g
    |> insert_cyclic_edge(v1, v2)
    |> insert_cyclic_edges(es)
  end

  @spec insert_cyclic_edge(Graph.t(), Vertex.id(), Vertex.id()) :: Graph.t()
  defp insert_cyclic_edge(g, v1, v2)

  defp insert_cyclic_edge(%Graph{} = g, {v1, _}, {v2, _}) do
    [v11, v12, v21, v22] =
      [{v1, :-}, {v1, :+}, {v2, :-}, {v2, :+}]
      |> Enum.map(&Graph.vertex(g, &1))

    [%{id: u1, label: %{r: r1}}, %{id: u2, label: %{r: r2}}] =
      [[v11, v21], [v11, v22], [v12, v21], [v12, v22]]
      |> Enum.sort_by(fn [%{label: %{r: r1}}, %{label: %{r: r2}}] -> {r2 > r1, abs(r2 - r1)} end)
      |> hd()

    if r2 > r1 do
      do_insert_cyclic_edge(g, u1, u2)
    else
      do_insert_cyclic_edge(g, u2, u1)
    end
  end

  defp insert_cyclic_edge(%Graph{} = g, v1, v2) do
    do_insert_cyclic_edge(g, v1, v2)
  end

  @spec do_insert_cyclic_edge(Graph.t(), Vertex.id(), Vertex.id()) :: Graph.t()
  defp do_insert_cyclic_edge(%Graph{} = g, v1, v2) do
    case Graph.add_edge(g, v1, v2) do
      {:error, _} -> Graph.add_edge(g, v2, v1, inverted: true)
      g -> g
    end
  end

  @spec do_rank_assignment([Vertex.id()], Graph.t(), non_neg_integer) :: Graph.t()
  defp do_rank_assignment([_ | _] = vs, %Graph{} = g, spacing) do
    Enum.reduce(vs, g, fn v, acc ->
      x = max_pred_rank(v, acc)

      r =
        case v do
          {_, :-} -> 1 + x
          {_, :+} -> 1 + x
          _ -> floor(1 + x / spacing) * spacing
        end

      Graph.put_label(acc, v, r: r)
    end)
  end

  defp max_pred_rank(v, g) do
    g
    |> Graph.in_neighbours(v)
    |> Enum.map(&Graph.vertex_label(g, &1))
    |> Enum.map(&Map.get(&1, :r))
    |> Enum.max(fn -> 0 end)
  end

  defp min_succ_rank(v, g) do
    g
    |> Graph.out_neighbours(v)
    |> Enum.map(&Graph.vertex_label(g, &1))
    |> Enum.map(&Map.get(&1, :r))
    |> Enum.min()
  end

  defp leaves_set(%Graph{} = t) do
    t
    |> Graph.sink_vertices()
    |> MapSet.new()
  end
end
