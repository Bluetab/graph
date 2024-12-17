defmodule Graph.CoordinateAssignment do
  @moduledoc """
  Coordinate assignment loosely based on Brandes and Köpf (2002), "Fast and
  Simple Horizontal Coordinate Assignment".
  """
  alias Graph.LevelGraph
  alias Graph.Traversal
  alias Graph.Vertex

  require Logger

  @type vertex :: Vertex.id()
  @type conflict :: {vertex, vertex}
  @type horizontal :: :left | :right
  @typep vertex_map :: %{vertex: vertex}

  @delta 2

  @spec assign_avg_x(LevelGraph.t()) :: LevelGraph.t()
  def assign_avg_x(%LevelGraph{g: g} = lg) do
    conflicts = type1_conflicts(lg)

    bgs =
      [:left, :right]
      |> Enum.flat_map(fn horizontal_direction ->
        Enum.map([:up, :down], fn vertical_direction ->
          lg
          |> vertical_alignment(conflicts, vertical_direction, horizontal_direction)
          |> horizontal_compaction(lg, horizontal_direction)
        end)
      end)
      |> align_to_narrowest()

    g
    |> Graph.vertices()
    |> Enum.reduce(lg, fn v, lg ->
      LevelGraph.put_label(lg, v, %{x: average_median(bgs, v, :x)})
    end)
  end

  @spec assign_x(LevelGraph.t(), Keyword.t()) :: LevelGraph.t()
  def assign_x(%LevelGraph{g: g} = lg, opts \\ []) do
    vdir = Keyword.get(opts, :vdir, :down)
    hdir = Keyword.get(opts, :hdir, :left)

    conflicts = type1_conflicts(lg)

    {root, bg} =
      lg
      |> vertical_alignment(conflicts, vdir, hdir)
      |> horizontal_compaction(lg, hdir)

    g
    |> Graph.vertices()
    |> Enum.reduce(lg, assign_x_reducer(bg, root, hdir))
  end

  @spec assign_x_reducer(Graph.t(), vertex_map, horizontal) ::
          (vertex, LevelGraph.t() -> LevelGraph.t())
  defp assign_x_reducer(%Graph{} = block_graph, %{} = roots, hdir) do
    fn v, lg ->
      with root <- Map.get(roots, v),
           x <- Graph.vertex(block_graph, root, :x) do
        LevelGraph.put_label(lg, v, %{x: x_pos(x, hdir)})
      end
    end
  end

  defp align_to_narrowest(bgs) do
    spans =
      bgs
      |> Enum.map(&x_span/1)

    [x_min, x_max] = Enum.min_by(spans, fn [min, max] -> max - min end)

    spans
    |> Enum.with_index()
    |> Enum.map(fn
      {[x, _], 0} when x > x_min -> x - x_min
      {[x, _], 1} when x > x_min -> x - x_min
      {[_, x], _} when x < x_max -> x_max - x
      _ -> 0
    end)
    |> Enum.map(fn x ->
      case x_min do
        0 -> x
        n -> x - n
      end
    end)
    |> Enum.zip(bgs)
    |> Enum.map(fn
      {0, lg} ->
        lg

      {n, {root, %Graph{} = g}} ->
        {root,
         g
         |> Graph.vertices(labels: true)
         |> Enum.map(fn {v, %{x: x}} -> {v, x + n} end)
         |> Enum.reduce(g, fn {v, x}, acc -> Graph.put_label(acc, v, x: x) end)}
    end)
  end

  defp x_span({_root, %Graph{} = g}) do
    g
    |> Graph.vertex_labels()
    |> Enum.map(&Map.get(&1, :x))
    |> Enum.min_max()
    |> Tuple.to_list()
  end

  defp average_median(bgs, v, label) do
    bgs
    |> Enum.map(fn {root, %Graph{} = g} ->
      v = Map.get(root, v)
      Graph.vertex(g, v, label)
    end)
    |> Enum.sort()
    |> Enum.slice(1, 2)
    |> Enum.reduce(fn x1, x2 -> (x1 + x2) / 2 end)
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

  @spec vertical_alignment(LevelGraph.t(), [conflict]) :: %{vertex: vertex}
  def vertical_alignment(%LevelGraph{g: g} = lg, conflicts, v_dir \\ :down, h_dir \\ :left) do
    vs = Graph.vertices(g)
    vertex_map = Map.new(vs, fn v -> {v, v} end)
    acc = %{root: vertex_map, align: vertex_map, r: 0, conflicts: MapSet.new(conflicts)}
    pos_fn = pos_fn(g, h_dir)
    nei_fn = nei_fn(g, pos_fn, v_dir)

    lg
    |> LevelGraph.vertices_by_level()
    |> sort_levels(v_dir)
    |> Enum.reduce(acc, fn {_level, vs}, acc -> do_vertical_alignment(acc, vs, pos_fn, nei_fn) end)
    |> Map.get(:root)
  end

  defp sort_levels(levels, :down), do: Enum.sort(levels)
  defp sort_levels(levels, :up), do: Enum.sort(levels, &(&1 >= &2))
  defp pos_fn(%Graph{} = g, :left), do: &Graph.vertex(g, &1, :b)
  # negate?
  defp pos_fn(%Graph{} = g, :right), do: &Graph.vertex(g, &1, :b)

  defp nei_fn(%Graph{} = g, pos_fn, direction) do
    fn v ->
      g
      |> neighbours(v, direction)
      |> Enum.sort_by(pos_fn)
    end
  end

  defp neighbours(%Graph{} = g, v, :down), do: Graph.in_neighbours(g, v)
  defp neighbours(%Graph{} = g, v, :up), do: Graph.out_neighbours(g, v)

  defp do_vertical_alignment(acc, vs, pos_fn, nei_fn) do
    vs
    |> Enum.sort_by(pos_fn)
    |> Enum.reduce(%{acc | r: 0}, fn v, acc ->
      case nei_fn.(v) do
        [] ->
          acc

        us ->
          mp = (Enum.count(us) - 1) / 2

          mp
          |> floor()
          |> Range.new(ceil(mp))
          |> Enum.reduce(acc, vertical_alignment_reducer(v, us, pos_fn))
      end
    end)
  end

  defp vertical_alignment_reducer(v, us, pos_fn) do
    fn m, %{align: align, root: root, r: r} = acc ->
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
    end
  end

  defp has_conflict?(%{conflicts: conflicts}, conflict) do
    MapSet.member?(conflicts, conflict)
  end

  @spec horizontal_compaction(vertex_map, LevelGraph.t(), horizontal) :: {vertex_map, Graph.t()}
  def horizontal_compaction(%{} = root, %LevelGraph{g: g} = lg, direction \\ :left) do
    bg =
      root
      |> create_block_graph(lg, direction)
      |> do_horizontal_compaction(direction)

    {root, assign_coordinates(root, bg, g)}
  end

  @spec assign_coordinates(vertex_map, Graph.t(), Graph.t()) :: Graph.t()
  defp assign_coordinates(root, bg, g) do
    root
    |> Enum.map(fn {v, root} -> {v, Graph.vertex(bg, root, :x)} end)
    |> Enum.reduce(g, fn {v, x}, acc -> Graph.put_label(acc, v, x: x) end)
  end

  defp x_pos(x, :left), do: x
  defp x_pos(x, :right), do: 0 - x

  defp do_horizontal_compaction(%Graph{} = g, direction) do
    vs = Traversal.topsort(g)

    g
    |> do_horizontal_compaction_right(vs, direction)
    |> do_horizontal_compaction_left(vs, direction)
  end

  defp do_horizontal_compaction_right(%Graph{} = g, vs, dir) do
    Enum.reduce(vs, g, &Graph.put_label(&2, &1, %{x: xr(&2, &1, dir) + delta(dir)}))
  end

  defp do_horizontal_compaction_left(%Graph{} = g, vs, dir) do
    vs
    |> Enum.reverse()
    |> Enum.reduce(g, &Graph.put_label(&2, &1, %{x: xl(&2, &1, dir) - delta(dir)}))
  end

  defp delta(:left), do: @delta
  defp delta(:right), do: -@delta

  defp xr(g, v, direction) do
    g
    |> Graph.in_neighbours(v)
    |> Enum.map(&Graph.vertex(g, &1, :x))
    |> h_max(direction)
  end

  defp xl(g, v, dir) do
    case Graph.out_neighbours(g, v) do
      [] ->
        Graph.vertex(g, v, :x) + if dir == :left, do: 1, else: -1

      ws ->
        ws
        |> Enum.map(&Graph.vertex(g, &1, :x))
        |> h_min(dir)
    end
  end

  defp h_max(xs, :left), do: Enum.max(xs, fn -> -1 end)
  defp h_max(xs, :right), do: Enum.min(xs, fn -> 1 end)
  defp h_min(xs, :left), do: Enum.min(xs)
  defp h_min(xs, :right), do: Enum.max(xs)

  defp create_block_graph(%{} = root, %LevelGraph{g: g} = lg, direction) do
    root
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
    |> Map.keys()
    |> Enum.reduce(
      Graph.new([], acyclic: true),
      &Graph.add_vertex(&2, &1, Graph.vertex_label(g, &1))
    )
    |> add_block_edges(root, lg, direction)
  end

  defp add_block_edges(%Graph{} = g, %{} = root, %LevelGraph{} = lg, direction) do
    lg
    |> LevelGraph.predecessor_map(direction)
    |> Enum.sort()
    |> Enum.flat_map(fn {v1, v2} -> [v1, v2] end)
    |> Enum.map(&Map.get(root, &1))
    |> Enum.chunk_every(2, 2)
    |> Enum.uniq()
    |> Enum.reduce(g, fn [v1, v2], acc ->
      case Graph.add_edge(acc, v2, v1) do
        {:error, e} ->
          Logger.warning("Cyclic edge: #{inspect({v2, v1})} #{inspect(e)}")
          acc

        g ->
          g
      end
    end)
  end
end
