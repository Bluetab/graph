defmodule Graph.Drawing.Grid do
  @moduledoc """
  Support for creating grid-based graph drawings.
  """

  alias Graph.Drawing.Dimensions
  alias Graph.Layout
  alias Graph.LevelGraph

  defstruct x_scale: %{}, y_scale: %{}

  @type t :: %__MODULE__{x_scale: %{pos_integer: pos_integer}, y_scale: %{float: pos_integer}}

  @default_x_padding 80
  @default_x_spacing 20
  @default_y_spacing 10

  def new(%Layout{graph: %{g: lg}}, opts) do
    new(lg, Dimensions.width_fn(), Dimensions.height_fn(), opts)
  end

  def new(%LevelGraph{g: g} = lg, width_fn, height_fn, opts \\ []) do
    y_scale =
      g
      |> Graph.vertices()
      |> Enum.group_by(y_pos(g, opts[:y_label]), height_fn)
      |> Enum.map(fn {y, vs} -> {y, Enum.max(vs)} end)
      |> Enum.sort()
      |> Enum.reduce([], &accumulate_height(&1, &2, y_spacing(opts)))
      |> Map.new(&y_entry/1)

    x_scale =
      lg
      |> LevelGraph.vertices_by_level()
      |> Enum.map(fn {x, vs} -> {x, max_width(vs, width_fn), Enum.find(vs, &delimiter?/1)} end)
      |> Enum.sort()
      |> Enum.reduce({[], nil}, &accumulate_width(&1, &2, x_spacing(opts), padding_fn(opts)))
      |> elem(0)
      |> Map.new(&x_entry/1)

    %__MODULE__{x_scale: x_scale, y_scale: y_scale}
  end

  def coords(%__MODULE__{x_scale: xs, y_scale: ys}, %{x: y, r: x}) do
    {xs[x], ys[y]}
  end

  def x_span(%__MODULE__{x_scale: xs}, {x_min, x_max}) do
    Enum.map([x_min, x_max], &Map.get(xs, &1))
  end

  def y_span(%__MODULE__{y_scale: ys}, {y_min, y_max}) do
    Enum.map([y_min, y_max], &Map.get(ys, &1))
  end

  defp x_entry({x, w, left, right}) do
    {x, %{w: w, left: left, right: right, mid: div(left + right, 2)}}
  end

  defp y_entry({y, h, top, bottom}) do
    {y, %{h: h, top: top, bottom: bottom, mid: div(top + bottom, 2)}}
  end

  defp max_width(vs, width_fn) do
    vs
    |> Enum.map(width_fn)
    |> Enum.max()
  end

  defp x_spacing(opts) when is_list(opts) do
    Keyword.get(opts, :x_spacing, @default_x_spacing)
  end

  defp y_spacing(opts) when is_list(opts) do
    Keyword.get(opts, :y_spacing, @default_y_spacing)
  end

  defp y_pos(%Graph{} = g, nil), do: y_pos(g, :x)
  defp y_pos(%Graph{} = g, label), do: &Graph.vertex(g, &1, label)

  defp accumulate_height({y, h}, [], _), do: [{y, h, 0, h}]

  defp accumulate_height({y, h}, [{_y1, _h1, _top, bottom} | _] = acc, spacing) do
    spacing = if h == 0, do: 0, else: spacing
    [{y, h, spacing + bottom, spacing + bottom + h} | acc]
  end

  defp accumulate_width({x, width, v}, {[], _}, _spacing, _padding_fn) do
    {[{x, width, 0, width}], v}
  end

  defp accumulate_width({x, width, v}, {[{_, _, _, right} | _] = acc, w}, spacing, padding_fn) do
    padding = padding_fn.(v, w)
    {[{x, width, padding + spacing + right, padding + spacing + right + width} | acc], v}
  end

  defp delimiter?({_, :-}), do: true
  defp delimiter?({_, :+}), do: true
  defp delimiter?(_), do: false

  defp padding_fn(opts) do
    p = Keyword.get(opts, :x_padding, @default_x_padding)

    fn
      {_, :+}, {_, :-} -> p
      {_, :-}, {_, :+} -> p
      _, _ -> 0
    end
  end
end
