defmodule Bluetab.Graph.NestingGraph do
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

  alias Bluetab.Graph.ClusteredLevelGraph
  alias Bluetab.Graph.ClusterTree
  alias Bluetab.Graph.LevelGraph
  alias Bluetab.Graph.Vertex

  defstruct g: %Bluetab.Graph{opts: [acyclic: true]},
            t: %Bluetab.Graph{opts: [acyclic: true]},
            cycles: []

  @type t :: %__MODULE__{
          g: Bluetab.Graph.t(),
          t: Bluetab.Graph.t(),
          cycles: [{Vertex.id(), Vertex.id()}]
        }

  @spec new(Bluetab.Graph.t(), Bluetab.Graph.t()) :: ClusteredLevelGraph.t()
  def new(%Bluetab.Graph{} = g, %Bluetab.Graph{} = t) do
    {ng, cycles} =
      t
      |> nodes()
      |> Bluetab.Graph.new(acyclic: true)
      |> add_nesting_edges(t)
      |> add_connectivity_edges(g, t)

    t =
      t
      |> ClusterTree.clusters()
      |> Enum.reduce(t, fn v, acc ->
        acc
        |> Bluetab.Graph.add_vertex({v, :-})
        |> Bluetab.Graph.add_vertex({v, :+})
        |> Bluetab.Graph.add_edge(v, {v, :-})
        |> Bluetab.Graph.add_edge(v, {v, :+})
      end)

    %__MODULE__{g: ng, t: t, cycles: cycles}
    |> rank_assignment()
    |> delete_nesting_edges()
    |> insert_cyclic_edges(cycles)
    |> LevelGraph.new(:r)
    |> ClusteredLevelGraph.new(t)
  end

  @spec add_nesting_edges(Bluetab.Graph.t(), Bluetab.Graph.t()) :: Bluetab.Graph.t()
  defp add_nesting_edges(%Bluetab.Graph{} = ng, %Bluetab.Graph{} = t) do
    t
    |> Bluetab.Graph.get_edges()
    |> Enum.reduce(ng, fn %{v1: v1, v2: v2}, acc ->
      if Bluetab.Graph.has_vertex?(ng, v2) do
        acc
        |> Bluetab.Graph.add_edge({v1, :-}, v2, nesting: true)
        |> Bluetab.Graph.add_edge(v2, {v1, :+}, nesting: true)
      else
        acc
        |> Bluetab.Graph.add_edge({v1, :-}, {v2, :-}, nesting: true)
        |> Bluetab.Graph.add_edge({v2, :+}, {v1, :+}, nesting: true)
      end
    end)
  end

  @spec add_connectivity_edges(Bluetab.Graph.t(), Bluetab.Graph.t(), Bluetab.Graph.t()) ::
          {Bluetab.Graph.t(), [{Vertex.id(), Vertex.id()}]}
  def add_connectivity_edges(%Bluetab.Graph{} = ng, %Bluetab.Graph{} = g, %Bluetab.Graph{} = t) do
    is_leaf? = &MapSet.member?(leaves_set(t), &1)

    g
    |> Bluetab.Graph.get_edges()
    |> Enum.map(fn %{v1: v1, v2: v2} -> edge_spec(t, v1, v2, is_leaf?.(v1), is_leaf?.(v2)) end)
    |> Enum.sort()
    |> Enum.reduce({ng, []}, &add_edge/2)
  end

  def add_labels(%Bluetab.Graph{} = ng, %Bluetab.Graph{} = g, labels) do
    g
    |> Bluetab.Graph.vertices(labels: true)
    |> Enum.map(fn {v, l} -> {v, Map.take(l, labels)} end)
    |> Enum.reduce(ng, fn {v, label}, ng -> Bluetab.Graph.put_label(ng, v, label) end)
  end

  @spec edge_spec(Bluetab.Graph.t(), Vertex.id(), Vertex.id(), boolean, boolean) ::
          {pos_integer, Vertex.id(), Vertex.id()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp edge_spec(t, v1, v2, v1_is_leaf, v2_is_leaf) do
    cond do
      v1_is_leaf and v2_is_leaf -> {1, v1, v2}
      v2_is_leaf and Bluetab.Graph.get_path(t, v1, v2) -> {2, {v1, :-}, v2}
      v2_is_leaf -> {3, {v1, :+}, v2}
      v1_is_leaf and Bluetab.Graph.get_path(t, v2, v1) -> {4, v1, {v2, :+}}
      v1_is_leaf -> {5, v1, {v2, :-}}
      Bluetab.Graph.get_path(t, v1, v2) -> {6, {v1, :-}, {v2, :-}}
      Bluetab.Graph.get_path(t, v2, v1) -> {7, {v1, :+}, {v2, :+}}
      true -> {8, {v1, :+}, {v2, :-}}
    end
  end

  @spec add_edge(
          {pos_integer, Vertex.id(), Vertex.id()},
          {Bluetab.Graph.t(), [{Vertex.id(), Vertex.id()}]}
        ) :: {Bluetab.Graph.t(), [{Vertex.id(), Vertex.id()}]}
  defp add_edge({_, v1, v2}, {%Bluetab.Graph{} = g, cycles}) do
    case Bluetab.Graph.add_edge(g, v1, v2) do
      %Bluetab.Graph{} = g ->
        {g, cycles}

      {:error, {:bad_edge, _path}} ->
        {g, [{v1, v2} | cycles]}
    end
  end

  @spec nodes(Bluetab.Graph.t()) :: [Vertex.id()]
  defp nodes(%Bluetab.Graph{} = t) do
    t
    |> ClusterTree.clusters()
    |> Enum.flat_map(fn v -> [{v, :-}, {v, :+}] end)
    |> Enum.concat(ClusterTree.leaves(t))
  end

  @spec rank_assignment(t) :: Bluetab.Graph.t()
  def rank_assignment(%__MODULE__{g: g, t: t}) do
    k = ClusterTree.depth(t)
    vs = Bluetab.Graph.Traversal.topsort(g)

    g =
      vs
      |> do_rank_assignment(g, 2 * k + 1)
      |> adjust_upper_borders(Enum.reverse(vs))

    vs
    |> Enum.group_by(&rank(g, &1))
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {vs, r} -> Enum.map(vs, &{&1, r}) end)
    |> Enum.reduce(g, fn {v, r}, acc -> Bluetab.Graph.put_label(acc, v, r: r) end)
  end

  @spec adjust_upper_borders(Bluetab.Graph.t(), [Vertex.id()]) :: Bluetab.Graph.t()
  defp adjust_upper_borders(g, vs)
  defp adjust_upper_borders(%Bluetab.Graph{} = g, []), do: g

  defp adjust_upper_borders(%Bluetab.Graph{} = g, [{_, :-} = v | vs]) do
    g
    |> Bluetab.Graph.put_label(v, r: min_succ_rank(v, g) - 1)
    |> adjust_upper_borders(vs)
  end

  defp adjust_upper_borders(%Bluetab.Graph{} = g, [_ | vs]) do
    adjust_upper_borders(g, vs)
  end

  @spec rank(Bluetab.Graph.t(), Vertex.id()) :: pos_integer
  defp rank(g, v) do
    g
    |> Bluetab.Graph.vertex_label(v)
    |> Map.get(:r)
  end

  @spec delete_nesting_edges(Bluetab.Graph.t()) :: Bluetab.Graph.t()
  defp delete_nesting_edges(%Bluetab.Graph{} = g) do
    g
    |> Bluetab.Graph.get_edges()
    |> Enum.filter(fn %{label: l} -> Map.get(l, :nesting) end)
    |> Enum.reduce(g, fn %{id: edge_id}, acc -> Bluetab.Graph.del_edge(acc, edge_id) end)
  end

  @spec insert_cyclic_edges(Bluetab.Graph.t(), [{Vertex.id(), Vertex.id()}]) :: Bluetab.Graph.t()
  defp insert_cyclic_edges(g, edges)

  defp insert_cyclic_edges(%Bluetab.Graph{} = g, []), do: g

  defp insert_cyclic_edges(%Bluetab.Graph{} = g, [{v1, v2} | es]) do
    g
    |> insert_cyclic_edge(v1, v2)
    |> insert_cyclic_edges(es)
  end

  @spec insert_cyclic_edge(Bluetab.Graph.t(), Vertex.id(), Vertex.id()) :: Bluetab.Graph.t()
  defp insert_cyclic_edge(g, v1, v2)

  defp insert_cyclic_edge(%Bluetab.Graph{} = g, {v1, _}, {v2, _}) do
    [v11, v12, v21, v22] =
      [{v1, :-}, {v1, :+}, {v2, :-}, {v2, :+}]
      |> Enum.map(&Bluetab.Graph.vertex(g, &1))

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

  defp insert_cyclic_edge(%Bluetab.Graph{} = g, v1, v2) do
    do_insert_cyclic_edge(g, v1, v2)
  end

  @spec do_insert_cyclic_edge(Bluetab.Graph.t(), Vertex.id(), Vertex.id()) :: Bluetab.Graph.t()
  defp do_insert_cyclic_edge(%Bluetab.Graph{} = g, v1, v2) do
    case Bluetab.Graph.add_edge(g, v1, v2) do
      {:error, _} -> Bluetab.Graph.add_edge(g, v2, v1, inverted: true)
      g -> g
    end
  end

  @spec do_rank_assignment([Vertex.id()], Bluetab.Graph.t(), non_neg_integer) :: Bluetab.Graph.t()
  defp do_rank_assignment([_ | _] = vs, %Bluetab.Graph{} = g, spacing) do
    Enum.reduce(vs, g, fn v, acc ->
      x = max_pred_rank(v, acc)

      r =
        case v do
          {_, :-} ->
            1 + x

          {_, :+} ->
            1 + x

          _ ->
            shift = Bluetab.Graph.vertex(g, v, :shift) || 0
            (shift + floor(1 + x / spacing)) * spacing
        end

      Bluetab.Graph.put_label(acc, v, r: r)
    end)
  end

  defp max_pred_rank(v, g) do
    g
    |> Bluetab.Graph.in_neighbours(v)
    |> Enum.map(&Bluetab.Graph.vertex_label(g, &1))
    |> Enum.map(&Map.get(&1, :r))
    |> Enum.max(fn -> 0 end)
  end

  defp min_succ_rank(v, g) do
    g
    |> Bluetab.Graph.out_neighbours(v)
    |> Enum.map(&Bluetab.Graph.vertex_label(g, &1))
    |> Enum.map(&Map.get(&1, :r))
    |> Enum.min()
  end

  defp leaves_set(%Bluetab.Graph{} = t) do
    t
    |> Bluetab.Graph.sink_vertices()
    |> MapSet.new()
  end
end
