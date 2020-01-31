defmodule Graph.Drawing do
  alias Graph.ClusteredLevelGraph
  alias Graph.Drawing.Grid
  alias Graph.Layout
  alias Graph.LevelGraph

  @derive Jason.Encoder
  defstruct groups: [],
            paths: [],
            resources: [],
            ids: [],
            excludes: [],
            opts: %{}

  @type t :: %__MODULE__{
          groups: list,
          paths: list,
          resources: list,
          ids: list,
          excludes: list,
          opts: map
        }
  @type label_fn :: (Graph.Vertex.label() -> map)
  @type type :: :lineage | :impact

  @spec new(Layout.t(), label_fn, Keyword.t()) :: t
  def new(%Layout{graph: graph, ids: ids, opts: layout_opts} = layout, label_fn, opts \\ []) do
    with %Grid{} = grid <- Grid.new(layout, opts),
         excludes <- Keyword.get(layout_opts, :excludes, []) do
      groups = groups(graph, grid, label_fn)
      resources = resources(graph, grid, label_fn)
      paths = paths(graph, grid, layout_opts[:type])
      opts = (layout_opts ++ opts) |> Map.new() |> Map.delete(:excludes)

      %__MODULE__{
        groups: groups,
        paths: paths,
        resources: resources,
        excludes: excludes,
        ids: ids,
        opts: opts
      }
    end
  end

  @spec resources(ClusteredLevelGraph.t(), Grid.t(), label_fn) :: list
  def resources(%ClusteredLevelGraph{g: lg}, %Grid{} = grid, label_fn) do
    resources(lg, grid, label_fn)
  end

  @spec resources(LevelGraph.t(), Grid.t(), label_fn) :: list
  def resources(%LevelGraph{g: g}, %Grid{} = grid, label_fn) do
    g
    |> Graph.vertices(labels: true)
    |> Enum.reject(fn {v, _l} -> is_tuple(v) end)
    |> Enum.map(fn {_, label} ->
      with {%{left: x, w: w}, %{top: y, h: h}} <- Grid.coords(grid, label),
           l <- label_fn.(label) do
        Map.merge(l, %{x: x, y: y, w: w, h: h})
      end
    end)
    |> Enum.sort_by(fn %{x: x, y: y} -> {x, y} end)
  end

  @spec paths(ClusteredLevelGraph.t(), Grid.t(), type) :: list
  def paths(%ClusteredLevelGraph{g: lg}, %Grid{} = g, type) do
    paths(lg, g, type)
  end

  @spec paths(LevelGraph.t(), Grid.t(), type) :: list
  def paths(%LevelGraph{g: g}, %Grid{} = grid, type) do
    path_fn = polyline_fn(g, grid, type)

    g
    |> Graph.get_edges(fn {_, {v1, v2, label}} -> {v1, v2, label} end)
    |> Enum.reject(fn {v1, v2, _} -> is_border?(v1) or is_border?(v2) end)
    |> Enum.group_by(&endpoints/1, fn {v1, v2, _} -> [v1, v2] end)
    |> Enum.map(path_fn)
  end

  @spec groups(ClusteredLevelGraph.t(), Grid.t(), label_fn) :: list
  def groups(%ClusteredLevelGraph{t: t}, %Grid{} = grid, label_fn) do
    groups(t, grid, label_fn)
  end

  @spec groups(Graph.t(), Grid.t(), label_fn) :: list
  def groups(%Graph{} = t, %Grid{} = grid, label_fn) do
    t
    |> Graph.vertex_labels()
    |> Enum.filter(&Map.has_key?(&1, :z))
    |> Enum.map(fn
      %{r: xs, x: ys, z: z} = label ->
        with [y_min, y_max] <- Grid.y_span(grid, ys),
             [x_min, x_max] <- Grid.x_span(grid, xs),
             l <- label_fn.(label) do
          l
          |> Map.merge(%{
            x: x_min[:left],
            y: y_min[:top],
            z: z,
            w: x_max[:right] - x_min[:left],
            h: y_max[:bottom] - y_min[:top]
          })
        end
    end)
    |> Enum.sort_by(fn %{x: x, y: y, z: z} -> {z, x, y} end)
  end

  defp endpoints({{v1, v2, _}, {v1, v2, _}, %{} = l}), do: {v1, v2, l[:inverted]}
  defp endpoints({{v1, v2, _}, v2, %{} = l}), do: {v1, v2, l[:inverted]}
  defp endpoints({v1, {v1, v2, _}, %{} = l}), do: {v1, v2, l[:inverted]}
  defp endpoints({v1, v2, %{} = l}), do: {v1, v2, l[:inverted]}

  defp polyline_fn(%Graph{} = g, %Grid{} = grid, type) do
    fn {{v1, v2, inverted}, vs} ->
      path =
        vs
        |> Enum.flat_map(& &1)
        |> MapSet.new()
        |> Enum.sort_by(sorter(g, type, inverted))
        |> Enum.map(&Graph.vertex_label(g, &1))
        |> Enum.map(&Grid.coords(grid, &1))
        |> Enum.chunk_every(2, 1)
        |> Enum.reduce([], path_reducer(type, inverted))
        |> Enum.reverse()
        |> Enum.join(" ")

      %{v1: v1, v2: v2, path: path}
    end
  end

  defp sorter(g, :lineage, true), do: sorter(g, :impact, false)
  defp sorter(g, :lineage, _falsey), do: sorter(g, :impact, true)

  defp sorter(g, :impact, true), do: &(0 - Graph.vertex(g, &1, :r))
  defp sorter(g, :impact, _falsey), do: &Graph.vertex(g, &1, :r)

  defp path_reducer(:lineage, true), do: path_reducer(:impact, false)
  defp path_reducer(:lineage, _falsey), do: path_reducer(:impact, true)

  defp path_reducer(:impact, true = _inverted) do
    fn
      [{%{left: x}, %{mid: y}} | _], [] -> ["M #{x} #{y}"]
      [{%{mid: x}, %{mid: y}}, _], acc -> ["L #{x} #{y}" | acc]
      [{%{right: x}, %{mid: y}}], acc -> ["L #{x} #{y}" | acc]
    end
  end

  defp path_reducer(:impact, _not_inverted) do
    fn
      [{%{right: x}, %{mid: y}} | _], [] -> ["M #{x} #{y}"]
      [{%{mid: x}, %{mid: y}}, _], acc -> ["L #{x} #{y}" | acc]
      [{%{left: x}, %{mid: y}}], acc -> ["L #{x} #{y}" | acc]
    end
  end

  defp is_border?({:l, _, _}), do: true
  defp is_border?({:r, _, _}), do: true
  defp is_border?({_, :-}), do: true
  defp is_border?({_, :+}), do: true
  defp is_border?(_), do: false
end
