defmodule Graph.Layout do
  alias Graph.RankAssignment
  alias Graph.CrossingReduction
  alias Graph.CoordinateAssignment
  alias Graph.ClusteredLevelGraph
  alias Graph.ClusterTree
  alias Graph.LevelGraph

  defstruct graph: %ClusteredLevelGraph{}, ids: [], opts: []

  @type t :: %__MODULE__{graph: ClusteredLevelGraph.t(), ids: [vertex], opts: Keyword.t()}
  @type vertex :: Graph.Vertex.id()

  @spec new(ClusteredLevelGraph.t(), [vertex], Keyword.t()) :: t
  def new(%ClusteredLevelGraph{} = clg, ids, opts) do
    %__MODULE__{graph: clg, ids: ids, opts: opts}
  end

  @spec layout(Graph.t(), Graph.t(), [vertex], Keyword.t()) :: t
  def layout(%Graph{} = g, %Graph{} = t, ids, opts \\ []) do
    g
    |> RankAssignment.assign_rank(t, ids)
    |> CrossingReduction.clustered_crossing_reduction()
    |> assign_coordinates()
    |> new(ids, opts)
  end

  @spec assign_coordinates(ClusteredLevelGraph.t()) :: ClusteredLevelGraph.t()
  defp assign_coordinates(%ClusteredLevelGraph{g: lg} = clg) do
    case assign_coordinates(lg) do
      %LevelGraph{} = lg ->
        %{clg | g: lg}
        |> assign_cluster_coordinates()
    end
  end

  @spec assign_coordinates(LevelGraph.t()) :: LevelGraph.t()
  defp assign_coordinates(%LevelGraph{} = lg) do
    CoordinateAssignment.assign_avg_x(lg)
  end

  defp assign_cluster_coordinates(%ClusteredLevelGraph{g: %{g: g} = lg, t: t} = clg) do
    t =
      g
      |> Graph.vertices()
      |> Enum.reduce(t, leaf_coordinate_reducer(g))

    case ClusterTree.post_order_clusters(t) do
      ws ->
        t =
          ws
          |> Enum.reverse()
          |> Enum.reduce(t, &do_assign_cluster_depth/2)

        t = Enum.reduce(ws, t, &do_assign_cluster_coordinates/2)
        lg = Enum.reduce(ws, lg, adjust_border_reducer(t))

        %{clg | t: t, g: lg}
    end
  end

  defp do_assign_cluster_depth(w, %Graph{} = t) do
    z =
      case Graph.in_neighbours(t, w) do
        ws ->
          ws
          |> Enum.map(&Graph.vertex(t, &1, :z))
          |> Enum.max(fn -> -1 end)
      end

    Graph.put_label(t, w, z: z + 1)
  end

  defp adjust_border_reducer(%Graph{} = t) do
    fn w, %LevelGraph{} = lg ->
      {min, max} = Graph.vertex(t, w, :x)

      t
      |> Graph.out_neighbours(w)
      |> Enum.filter(&is_border?/1)
      |> Enum.reduce(lg, fn
        {:l, _, _} = v, lg -> LevelGraph.put_label(lg, v, x: min)
        {:r, _, _} = v, lg -> LevelGraph.put_label(lg, v, x: max)
      end)
    end
  end

  def leaf_coordinate_reducer(%Graph{} = g) do
    fn v, %Graph{} = t ->
      case Graph.vertex_label(g, v) do
        %{x: x, r: r} -> Graph.put_label(t, v, x: {x, x}, r: {r, r})
      end
    end
  end

  def do_assign_cluster_coordinates(w, %Graph{} = t) do
    t
    |> child_coordinates(w)
    |> put_label(t, w)
  end

  defp put_label(%{x: x, r: r}, %Graph{} = t, w) do
    Graph.put_label(t, w, r: r, x: x)
  end

  defp child_coordinates(%Graph{} = t, w) do
    case Graph.out_neighbours(t, w) do
      vs ->
        x =
          vs
          |> Enum.reject(&is_dummy?/1)
          |> Enum.map(&Graph.vertex(t, &1, :x))
          |> Enum.flat_map(&Tuple.to_list/1)
          |> Enum.min_max()
          |> expand(2, 2)

        r =
          vs
          |> Enum.filter(&is_y_border?/1)
          |> Enum.map(&Graph.vertex(t, &1, :r))
          |> Enum.flat_map(&Tuple.to_list/1)
          |> Enum.min_max()

        %{x: x, r: r}
    end
  end

  defp is_border?({:l, _, _}), do: true
  defp is_border?({:r, _, _}), do: true
  defp is_border?(_), do: false

  defp is_dummy?({_, :-}), do: true
  defp is_dummy?({_, :+}), do: true
  defp is_dummy?({:l, _, _}), do: true
  defp is_dummy?({:r, _, _}), do: true
  defp is_dummy?({_v1, _v2, r}) when is_integer(r), do: true
  defp is_dummy?(_), do: false

  defp is_y_border?({_, :-}), do: true
  defp is_y_border?({_, :+}), do: true
  defp is_y_border?(_), do: false

  defp expand({min, max}, d1, d2), do: {min - d1, max + d2}
end
