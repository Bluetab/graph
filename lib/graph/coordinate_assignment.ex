defmodule Graph.CoordinateAssignment do
  @moduledoc """
  Coordinate assignment loosely based on Brandes and Köpf (2002), "Fast and
  Simple Horizontal Coordinate Assignment".
  """
  alias Graph.LevelGraph
  alias Graph.Traversal
  alias Graph.Vertex

  @type vertex :: Vertex.id()
  @type conflict :: {vertex, vertex}

  @delta 1

  @spec assign_x(LevelGraph.t()) :: LevelGraph.t()
  def assign_x(%LevelGraph{} = lg) do
    lg
    |> type1_conflicts()
    |> do_vertical_alignment(lg)
    |> horizontal_compaction(lg)
  end

  @spec type1_conflicts(LevelGraph.t()) :: [conflict]
  def type1_conflicts(%LevelGraph{g: g} = lg) do
    lg
    |> LevelGraph.vertices_by_level()
    |> Enum.sort()
    |> Enum.drop(1)
    |> Enum.map(fn {_level, vs} -> Enum.sort_by(vs, &Graph.vertex(g, &1, :b)) end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(&do_type1_conflicts(&1, g))
  end

  @spec do_type1_conflicts([[vertex]], Graph.t()) :: [conflict]
  defp do_type1_conflicts([us, vs], %Graph{} = g) do
    vs_count = Enum.count(vs)

    vs
    |> Enum.sort_by(&Graph.vertex(g, &1, :b))
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{k0: 0, l: 1, conflicts: []},
      fn {v, l1}, %{k0: k0, l: l, conflicts: conflicts} = acc ->
        case k1(l1, vs_count, us, g, v) do
          nil ->
            acc

          k1 ->
            uvs =
              vs
              |> Enum.slice(l - 1, l1 - l)
              |> Enum.map(&{&1, Graph.in_neighbours(g, &1)})
              |> Enum.flat_map(fn {v, us} -> Enum.map(us, &{&1, v}) end)
              |> Enum.group_by(fn {u, _v} -> Graph.vertex(g, u, :b) end)
              |> Enum.filter(fn {k, _uvs} -> k < k0 or k > k1 end)
              |> Enum.flat_map(fn {_k, uvs} -> uvs end)

            %{acc | k0: k1, l: l1 + 1, conflicts: conflicts ++ uvs}
        end
      end
    )
    |> Map.get(:conflicts)
  end

  @spec k1(pos_integer, pos_integer, [vertex], Graph.t(), vertex) :: pos_integer | nil
  defp k1(l1, lmax, us, g, v)

  defp k1(l1, l1, us, _g, _v), do: Enum.count(us)

  defp k1(_, _, _, g, v) do
    if Graph.vertex(g, v, :dummy) do
      g
      |> Graph.in_neighbours(v)
      |> Enum.filter(&Graph.vertex(g, &1, :dummy))
      |> Enum.map(&Graph.vertex(g, &1, :b))
      |> Enum.find(& &1)
    end
  end

  @spec do_vertical_alignment([conflict], LevelGraph.t()) :: %{vertex: vertex}
  def do_vertical_alignment(conflicts, %LevelGraph{} = lg) do
    vertical_alignment(lg, conflicts)
  end

  @spec vertical_alignment(LevelGraph.t(), [conflict]) :: %{vertex: vertex}
  def vertical_alignment(%LevelGraph{g: g} = lg, conflicts) do
    vs = Graph.vertices(g)
    vertex_map = Map.new(vs, fn v -> {v, v} end)
    acc = %{root: vertex_map, align: vertex_map, r: 0, conflicts: MapSet.new(conflicts)}
    pos_fn = fn v -> Graph.vertex(g, v, :b) end

    nei_fn = fn v ->
      g
      |> Graph.in_neighbours(v)
      |> Enum.sort_by(pos_fn)
    end

    lg
    |> LevelGraph.vertices_by_level()
    |> Enum.sort()
    |> Enum.reduce(acc, fn {_level, vs}, acc -> do_vertical_alignment(acc, vs, pos_fn, nei_fn) end)
    |> Map.get(:root)
  end

  defp do_vertical_alignment(acc, vs, pos_fn, nei_fn) do
    vs
    |> Enum.sort_by(pos_fn)
    |> Enum.reduce(%{acc | r: 0}, fn v, acc ->
      case nei_fn.(v) do
        [] ->
          acc

        us ->
          mp = (Enum.count(us) - 1) / 2

          floor(mp)
          |> Range.new(ceil(mp))
          |> Enum.reduce(acc, fn m, %{align: align, root: root, r: r} = acc ->
            case Map.get(align, v) do
              ^v ->
                u = Enum.at(us, m)
                pos_u = pos_fn.(u)

                if r < pos_u and not has_conflict?(acc, {u, v}) do
                  %{
                    acc
                    | align: %{align | u => v, v => root[u]},
                      root: %{root | v => root[u]},
                      r: pos_u
                  }
                else
                  acc
                end

              _ ->
                acc
            end
          end)
      end
    end)
  end

  defp has_conflict?(%{conflicts: conflicts}, conflict) do
    MapSet.member?(conflicts, conflict)
  end

  @spec horizontal_compaction(%{vertex: vertex}, LevelGraph.t()) :: LevelGraph.t()
  def horizontal_compaction(%{} = root, %LevelGraph{} = lg) do
    bg =
      root
      |> create_block_graph(lg)
      |> do_horizontal_compaction()

    root
    |> Enum.map(fn {v, root} -> {v, Graph.vertex(bg, root, :x)} end)
    |> Enum.reduce(lg, fn {v, x}, acc -> LevelGraph.put_label(acc, v, %{x: x}) end)
  end

  defp do_horizontal_compaction(%Graph{} = g) do
    vs = Traversal.topsort(g)

    g
    |> do_horizontal_compaction_right(vs)
    |> do_horizontal_compaction_left(vs)
  end

  defp do_horizontal_compaction_right(%Graph{} = g, vs) do
    Enum.reduce(vs, g, &Graph.put_label(&2, &1, %{x: xr(&2, &1) + @delta}))
  end

  defp do_horizontal_compaction_left(%Graph{} = g, vs) do
    vs
    |> Enum.reverse()
    |> Enum.reduce(g, &Graph.put_label(&2, &1, %{x: xl(&2, &1) - @delta}))
  end

  defp xr(g, v) do
    g
    |> Graph.in_neighbours(v)
    |> Enum.map(&Graph.vertex(g, &1, :x))
    |> Enum.max(fn -> -1 end)
  end

  defp xl(g, v) do
    case Graph.out_neighbours(g, v) do
      [] ->
        Graph.vertex(g, v, :x) + 1

      ws ->
        ws
        |> Enum.map(&Graph.vertex(g, &1, :x))
        |> Enum.min()
    end
  end

  defp create_block_graph(%{} = root, %LevelGraph{g: g} = lg) do
    root
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
    |> Map.keys()
    |> Enum.reduce(Graph.new(), &Graph.add_vertex(&2, &1, Graph.vertex_label(g, &1)))
    |> add_block_edges(root, lg)
  end

  defp add_block_edges(%Graph{} = g, %{} = root, %LevelGraph{} = lg) do
    lg
    |> LevelGraph.predecessor_map()
    |> Enum.flat_map(fn {v1, v2} -> [v1, v2] end)
    |> Enum.map(&Map.get(root, &1))
    |> Enum.chunk_every(2, 2)
    |> Enum.uniq()
    |> Enum.reduce(g, fn [v1, v2], acc -> Graph.add_edge(acc, v2, v1) end)
  end
end
