defmodule Bluetab.Graph.RankAssignment do
  @moduledoc """
  Assigns a rank to the nodes of a clustered graph.
  """

  alias Bluetab.Graph.ClusteredLevelGraph
  alias Bluetab.Graph.ClusterTree
  alias Bluetab.Graph.CrossingReduction
  alias Bluetab.Graph.LevelGraph
  alias Bluetab.Graph.RangeMap
  alias Bluetab.Graph.RankAssignment.Chunk
  alias Bluetab.Graph.RankAssignment.Split
  alias Bluetab.Graph.Traversal
  alias Bluetab.Graph.Vertex

  @type rank :: pos_integer
  @type direction :: :out | :in
  @type edge_spec :: {Vertex.id(), Vertex.id()}

  @spec assign_rank(Bluetab.Graph.t(), [Vertex.id()]) :: Bluetab.Graph.t()
  def assign_rank(%Bluetab.Graph{} = g, ids) do
    g
    |> Bluetab.Graph.new(acyclic: true, edges: false)
    |> assign_min_rank(g, ids, 1)
    |> assign_max_rank()
  end

  @spec assign_rank(Bluetab.Graph.t(), Bluetab.Graph.t(), [Vertex.id()]) ::
          ClusteredLevelGraph.t()
  def assign_rank(%Bluetab.Graph{} = g, %Bluetab.Graph{} = t, ids) do
    g
    |> assign_rank(ids)
    |> assign_cluster_ranks(t)
  end

  @spec assign_max_rank(Bluetab.Graph.t()) :: Bluetab.Graph.t()
  defp assign_max_rank(%Bluetab.Graph{} = g) do
    g
    |> Traversal.topsort()
    |> Enum.reverse()
    |> Enum.reduce(g, fn v, g -> Bluetab.Graph.put_label(g, v, r_max: max_rank(g, v)) end)
  end

  defp max_rank(%Bluetab.Graph{} = g, v) do
    g
    |> Bluetab.Graph.out_neighbours(v)
    |> do_max_rank(g, v, maximum_rank(g))
  end

  defp maximum_rank(%Bluetab.Graph{} = g) do
    g
    |> Bluetab.Graph.vertices()
    |> Enum.map(&Bluetab.Graph.vertex(g, &1, :r_min))
    |> Enum.max()
  end

  defp do_max_rank([], %Bluetab.Graph{} = _g, _v, max_rank) do
    max_rank
  end

  defp do_max_rank(ws, %Bluetab.Graph{} = g, _v, _max_rank) do
    ws
    |> Enum.map(&Bluetab.Graph.vertex(g, &1, :r_max))
    |> Enum.min()
    |> Kernel.-(1)
  end

  @spec assign_cluster_ranks(Bluetab.Graph.t(), Bluetab.Graph.t()) :: ClusteredLevelGraph.t()
  def assign_cluster_ranks(%Bluetab.Graph{} = g, %Bluetab.Graph{} = t) do
    with vs <- Bluetab.Graph.sink_vertices(t),
         %Bluetab.Graph{} = t <- assign_leaf_spans(g, t, vs),
         ws <- ClusterTree.post_order_clusters(t) do
      ws
      |> Enum.reduce(t, &Bluetab.Graph.put_label(&2, &1, rs: assign_cluster_spans(&2, &1)))
      |> resolve_leaf_ranks(vs, g)
      |> resolve_cluster_ranks(ws)
      |> normalize(g)
    end
  end

  defp normalize(%Bluetab.Graph{} = t, %Bluetab.Graph{} = g) do
    k = ClusterTree.height(t)

    with %Bluetab.Graph{} = t <- Split.split_clusters(t),
         vs <- Bluetab.Graph.vertices(t) do
      {g, t} =
        vs
        |> Enum.group_by(&nesting_rank(t, &1, 2 * k + 1))
        |> Enum.reduce({g, t}, &put_nesting_rank/2)

      g =
        g
        |> Bluetab.Graph.vertices()
        |> Enum.group_by(&Bluetab.Graph.vertex(g, &1, :r))
        |> Enum.sort()
        |> Enum.map(fn {_, vs} -> vs end)
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {vs, r} -> Enum.map(vs, &{&1, r}) end)
        |> Enum.reduce(g, fn {v, r}, acc -> Bluetab.Graph.put_label(acc, v, r: r) end)

      do_normalize(g, t)
    end
  end

  @spec do_normalize(Bluetab.Graph.t(), Bluetab.Graph.t()) :: ClusteredLevelGraph.t()
  defp do_normalize(%Bluetab.Graph{} = g, %Bluetab.Graph{} = t) do
    g
    |> LevelGraph.new(:r)
    |> ClusteredLevelGraph.new(t)
    |> CrossingReduction.normalize()
  end

  defp nesting_rank(%Bluetab.Graph{} = t, v, spacing) do
    case Bluetab.Graph.vertex(t, v, :r) do
      r when is_integer(r) ->
        r * spacing

      r1..r2//_ ->
        h = ClusterTree.height(t, v)
        (r1 * spacing - h)..(r2 * spacing + h)

      [r1..r2//_] ->
        h = ClusterTree.height(t, v)
        (r1 * spacing - h)..(r2 * spacing + h)
    end
  end

  defp put_nesting_rank({r, vs}, {%Bluetab.Graph{} = g, %Bluetab.Graph{} = t})
       when is_integer(r) do
    {Enum.reduce(vs, g, &Bluetab.Graph.put_label(&2, &1, r: r)), t}
  end

  defp put_nesting_rank({r1..r2//_, ws}, {%Bluetab.Graph{} = g, %Bluetab.Graph{} = t}) do
    Enum.reduce(ws, {g, t}, fn w, {g, t} ->
      t =
        t
        |> Bluetab.Graph.add_vertex({w, :-})
        |> Bluetab.Graph.add_vertex({w, :+})
        |> Bluetab.Graph.add_edge(w, {w, :-})
        |> Bluetab.Graph.add_edge(w, {w, :+})

      g =
        g
        |> Bluetab.Graph.add_vertex({w, :-}, r: r1)
        |> Bluetab.Graph.add_vertex({w, :+}, r: r2)

      {g, t}
    end)
  end

  defp resolve_cluster_ranks(%Bluetab.Graph{} = t, ws) do
    Enum.reduce(ws, t, fn w, t ->
      rs =
        t
        |> Bluetab.Graph.out_neighbours(w)
        |> Enum.map(&Bluetab.Graph.vertex(t, &1, :r))
        |> Chunk.chunk()

      Bluetab.Graph.put_label(t, w, r: rs)
    end)
  end

  defp resolve_leaf_ranks(%Bluetab.Graph{} = t, vs, %Bluetab.Graph{} = g) do
    vs
    |> Enum.group_by(&Bluetab.Graph.in_neighbours(t, &1))
    |> Enum.map(fn {[cluster], vs} -> {Bluetab.Graph.vertex(t, cluster, :rs), vs} end)
    |> Enum.flat_map(fn {rs, vs} -> Enum.map(vs, &{&1, resolve_rank(t, &1, rs)}) end)
    |> Enum.reduce(t, fn {v, r}, t -> Bluetab.Graph.put_label(t, v, r: r) end)
    |> shift_leaf_ranks(g)
  end

  defp resolve_rank(%Bluetab.Graph{} = t, v, rs) do
    span =
      t
      |> Bluetab.Graph.vertex(v, :rs)
      |> RangeMap.span()

    rs
    |> Enum.filter(&Enum.member?(span, &1))
    |> Enum.min()
  end

  defp shift_leaf_ranks(%Bluetab.Graph{} = t, %Bluetab.Graph{} = g) do
    g
    |> Traversal.topsort()
    |> Enum.reduce(t, &shift_reducer(&2, &1, Bluetab.Graph.in_neighbours(g, &1)))
  end

  defp shift_reducer(%Bluetab.Graph{} = acc, _v, [] = _in_neighbours), do: acc

  defp shift_reducer(%Bluetab.Graph{} = acc, v, [_ | _] = in_neighbours) do
    r_min =
      in_neighbours
      |> Enum.map(&Bluetab.Graph.vertex(acc, &1, :r))
      |> Enum.max()
      |> Kernel.+(1)

    case Bluetab.Graph.vertex(acc, v, :r) do
      r when r < r_min -> Bluetab.Graph.put_label(acc, v, %{r: r_min})
      _ -> acc
    end
  end

  def assign_leaf_spans(%Bluetab.Graph{} = g, %Bluetab.Graph{} = t, vs) do
    Enum.reduce(vs, t, fn v, acc ->
      case Bluetab.Graph.vertex_label(g, v) do
        %{r_min: r_min, r_max: r_max} ->
          Bluetab.Graph.put_label(acc, v, rs: RangeMap.new([r_min..r_max]))
      end
    end)
  end

  def assign_cluster_spans(%Bluetab.Graph{} = t, w) do
    t
    |> Bluetab.Graph.out_neighbours(w)
    |> Enum.map(&Bluetab.Graph.vertex(t, &1, :rs))
    |> Enum.reduce(&union/2)
    |> cover()
  end

  defp union(%RangeMap{} = rm1, %RangeMap{} = rm2) do
    RangeMap.union(rm1, rm2)
  end

  defp union([_ | _] = rs1, [_ | _] = rs2) do
    rs2
    |> Enum.concat(rs1)
    |> Enum.uniq()
  end

  defp cover(%RangeMap{} = rm), do: RangeMap.greedy_cover(rm)
  defp cover([_ | _] = rs), do: rs

  @spec assign_min_rank(Bluetab.Graph.t(), Bluetab.Graph.t(), [Vertex.id()], rank) ::
          Bluetab.Graph.t()
  defp assign_min_rank(acc, g, ids, r)

  defp assign_min_rank(%Bluetab.Graph{} = acc, %Bluetab.Graph{}, [] = _ids, _r), do: acc

  defp assign_min_rank(%Bluetab.Graph{} = acc, %Bluetab.Graph{} = g, ids, r) do
    acc = Enum.reduce(ids, acc, &Bluetab.Graph.put_label(&2, &1, r_min: r))

    edges = edge_set(g, ids)

    edges
    |> Enum.reduce({acc, edges}, &insert_edge_acyclic/2)
    |> assign_next_rank(g, r + 1)
  end

  @spec assign_next_rank({Bluetab.Graph.t(), [edge_spec]}, Bluetab.Graph.t(), rank) ::
          Bluetab.Graph.t()
  defp assign_next_rank({%Bluetab.Graph{} = acc, acyclic_edges}, %Bluetab.Graph{} = g, r) do
    next_ids = Enum.map(acyclic_edges, fn {_v1, v2} -> v2 end)
    assign_min_rank(acc, g, next_ids, r)
  end

  @spec insert_edge_acyclic(edge_spec, {Bluetab.Graph.t(), MapSet.t()}) ::
          {Bluetab.Graph.t(), MapSet.t()}
  defp insert_edge_acyclic(
         {v1, v2},
         {%Bluetab.Graph{} = g, acyclic_edges} = acc,
         inverted \\ false
       ) do
    with false <- Bluetab.Graph.has_edge?(g, v1, v2),
         %Bluetab.Graph{} = g <- do_insert_edge(g, v1, v2, inverted) do
      {g, acyclic_edges}
    else
      true ->
        acc

      {:error, _} ->
        insert_edge_acyclic({v2, v1}, {g, MapSet.delete(acyclic_edges, {v1, v2})}, true)
    end
  end

  defp do_insert_edge(%Bluetab.Graph{} = g, v1, v2, true) do
    Bluetab.Graph.add_edge(g, v1, v2, inverted: true)
  end

  defp do_insert_edge(%Bluetab.Graph{} = g, v1, v2, false), do: Bluetab.Graph.add_edge(g, v1, v2)

  @spec edge_set(Bluetab.Graph.t(), [Vertex.id()]) :: MapSet.t()
  defp edge_set(%Bluetab.Graph{} = g, ids) do
    ids
    |> Enum.map(&Bluetab.Graph.out_neighbours(g, &1))
    |> Enum.zip(ids)
    |> Enum.flat_map(fn {v2s, v1} -> Enum.map(v2s, &{v1, &1}) end)
    |> Enum.reject(fn {v1, v2} -> v1 == v2 end)
    |> MapSet.new()
  end
end
