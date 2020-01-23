defmodule Graph.RankAssignment do
  alias Graph.ClusterTree
  alias Graph.ClusteredLevelGraph
  alias Graph.CrossingReduction
  alias Graph.LevelGraph
  alias Graph.RangeMap
  alias Graph.RankAssignment.Chunk
  alias Graph.RankAssignment.Split
  alias Graph.Traversal
  alias Graph.Vertex

  @type rank :: pos_integer
  @type direction :: :out | :in
  @type edge_spec :: {Vertex.id(), Vertex.id()}

  @spec assign_rank(Graph.t(), [Vertex.id()]) :: Graph.t()
  def assign_rank(%Graph{} = g, ids) do
    g
    |> Graph.new(acyclic: true, edges: false)
    |> assign_min_rank(g, ids, 1)
    |> assign_max_rank()
  end

  @spec assign_rank(Graph.t(), Graph.t(), [Vertex.id()]) :: ClusteredLevelGraph.t()
  def assign_rank(%Graph{} = g, %Graph{} = t, ids) do
    g
    |> assign_rank(ids)
    |> assign_cluster_ranks(t)
  end

  @spec assign_max_rank(Graph.t()) :: Graph.t()
  defp assign_max_rank(%Graph{} = g) do
    g
    |> Traversal.topsort()
    |> Enum.reverse()
    |> Enum.reduce(g, &Graph.put_label(&2, &1, r_max: max_rank(&2, &1)))
  end

  defp max_rank(%Graph{} = g, v) do
    g
    |> Graph.out_neighbours(v)
    |> do_max_rank(g, v)
  end

  defp do_max_rank([], %Graph{} = g, v), do: Graph.vertex(g, v, :r_min)

  defp do_max_rank(ws, %Graph{} = g, _v) do
    ws
    |> Enum.map(&Graph.vertex(g, &1, :r_min))
    |> Enum.min()
    |> Kernel.-(1)
  end

  @spec assign_cluster_ranks(Graph.t(), Graph.t()) :: ClusteredLevelGraph.t()
  def assign_cluster_ranks(%Graph{} = g, %Graph{} = t) do
    with vs <- Graph.sink_vertices(t),
         %Graph{} = t <- assign_leaf_spans(g, t, vs),
         ws <- ClusterTree.post_order_clusters(t) do
      ws
      |> Enum.reduce(t, &Graph.put_label(&2, &1, rs: assign_cluster_spans(&2, &1)))
      |> resolve_leaf_ranks(vs)
      |> resolve_cluster_ranks(ws)
      |> normalize(g)
    end
  end

  defp normalize(%Graph{} = t, %Graph{} = g) do
    k = ClusterTree.height(t)

    with %Graph{} = t <- Split.split_clusters(t),
         vs <- Graph.vertices(t) do
      {g, t} =
        vs
        |> Enum.group_by(&nesting_rank(t, &1, 2 * k + 1))
        |> Enum.reduce({g, t}, &put_nesting_rank/2)

      g =
        g
        |> Graph.vertices()
        |> Enum.group_by(&Graph.vertex(g, &1, :r))
        |> Enum.sort()
        |> Enum.map(fn {_, vs} -> vs end)
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {vs, r} -> Enum.map(vs, &{&1, r}) end)
        |> Enum.reduce(g, fn {v, r}, acc -> Graph.put_label(acc, v, r: r) end)

      do_normalize(g, t)
    end
  end

  @spec do_normalize(Graph.t(), Graph.t()) :: ClusteredLevelGraph.t()
  defp do_normalize(%Graph{} = g, %Graph{} = t) do
    g
    |> LevelGraph.new(:r)
    |> ClusteredLevelGraph.new(t)
    |> CrossingReduction.normalize()
  end

  defp nesting_rank(%Graph{} = t, v, spacing) do
    case Graph.vertex(t, v, :r) do
      r when is_integer(r) ->
        r * spacing

      r1..r2 ->
        h = ClusterTree.height(t, v)
        (r1 * spacing - h)..(r2 * spacing + h)

      [r1..r2] ->
        h = ClusterTree.height(t, v)
        (r1 * spacing - h)..(r2 * spacing + h)
    end
  end

  defp put_nesting_rank({r, vs}, {%Graph{} = g, %Graph{} = t}) when is_integer(r) do
    {Enum.reduce(vs, g, &Graph.put_label(&2, &1, r: r)), t}
  end

  defp put_nesting_rank({r1..r2, ws}, {%Graph{} = g, %Graph{} = t}) do
    Enum.reduce(ws, {g, t}, fn w, {g, t} ->
      t =
        t
        |> Graph.add_vertex({w, :-})
        |> Graph.add_vertex({w, :+})
        |> Graph.add_edge(w, {w, :-})
        |> Graph.add_edge(w, {w, :+})

      g =
        g
        |> Graph.add_vertex({w, :-}, r: r1)
        |> Graph.add_vertex({w, :+}, r: r2)

      {g, t}
    end)
  end

  defp resolve_cluster_ranks(%Graph{} = t, ws) do
    Enum.reduce(ws, t, fn w, t ->
      rs =
        t
        |> Graph.out_neighbours(w)
        |> Enum.map(&Graph.vertex(t, &1, :r))
        |> Chunk.chunk()

      Graph.put_label(t, w, r: rs)
    end)
  end

  defp resolve_leaf_ranks(%Graph{} = t, vs) do
    vs
    |> Enum.group_by(&Graph.in_neighbours(t, &1))
    |> Enum.map(fn {[cluster], vs} -> {Graph.vertex(t, cluster, :rs), vs} end)
    |> Enum.flat_map(fn {rs, vs} -> Enum.map(vs, &{&1, resolve_rank(t, &1, rs)}) end)
    |> Enum.reduce(t, fn {v, r}, t -> Graph.put_label(t, v, r: r) end)
  end

  defp resolve_rank(%Graph{} = t, v, rs) do
    span =
      t
      |> Graph.vertex(v, :rs)
      |> RangeMap.span()

    Enum.find(rs, &Enum.member?(span, &1))
  end

  def assign_leaf_spans(%Graph{} = g, %Graph{} = t, vs) do
    Enum.reduce(vs, t, fn v, acc ->
      case Graph.vertex_label(g, v) do
        %{r_min: r_min, r_max: r_max} ->
          Graph.put_label(acc, v, rs: RangeMap.new([r_min..r_max]))
      end
    end)
  end

  def assign_cluster_spans(%Graph{} = t, w) do
    t
    |> Graph.out_neighbours(w)
    |> Enum.map(&Graph.vertex(t, &1, :rs))
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

  @spec assign_min_rank(Graph.t(), Graph.t(), [Vertex.id()], rank) :: Graph.t()
  defp assign_min_rank(acc, g, ids, r)

  defp assign_min_rank(%Graph{} = acc, %Graph{}, [] = _ids, _r), do: acc

  defp assign_min_rank(%Graph{} = acc, %Graph{} = g, ids, r) do
    acc = Enum.reduce(ids, acc, &Graph.put_label(&2, &1, r_min: r))

    edges = edge_set(g, ids)

    edges
    |> Enum.reduce({acc, edges}, &insert_edge_acyclic/2)
    |> assign_next_rank(g, r + 1)
  end

  @spec assign_next_rank({Graph.t(), [edge_spec]}, Graph.t(), rank) :: Graph.t()
  defp assign_next_rank({%Graph{} = acc, acyclic_edges}, %Graph{} = g, r) do
    next_ids = Enum.map(acyclic_edges, fn {_v1, v2} -> v2 end)
    assign_min_rank(acc, g, next_ids, r)
  end

  @spec insert_edge_acyclic(edge_spec, {Graph.t(), MapSet.t()}) :: {Graph.t(), MapSet.t()}
  defp insert_edge_acyclic({v1, v2}, {%Graph{} = g, acyclic_edges} = acc, inverted \\ false) do
    with false <- Graph.has_edge?(g, v1, v2),
         %Graph{} = g <- do_insert_edge(g, v1, v2, inverted) do
      {g, acyclic_edges}
    else
      true ->
        acc

      {:error, _} ->
        insert_edge_acyclic({v2, v1}, {g, MapSet.delete(acyclic_edges, {v1, v2})}, true)
    end
  end

  defp do_insert_edge(%Graph{} = g, v1, v2, true) do
    Graph.add_edge(g, v1, v2, inverted: true)
  end

  defp do_insert_edge(%Graph{} = g, v1, v2, false), do: Graph.add_edge(g, v1, v2)

  @spec edge_set(Graph.t(), [Vertex.id()]) :: MapSet.t()
  defp edge_set(%Graph{} = g, ids) do
    ids
    |> Enum.map(&Graph.out_neighbours(g, &1))
    |> Enum.zip(ids)
    |> Enum.flat_map(fn {v2s, v1} -> Enum.map(v2s, &{v1, &1}) end)
    |> Enum.reject(fn {v1, v2} -> v1 == v2 end)
    |> MapSet.new()
  end
end
