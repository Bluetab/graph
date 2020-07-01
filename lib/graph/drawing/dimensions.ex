defmodule Graph.Drawing.Dimensions do
  @moduledoc """
  Module to calculate dimensions of nodes in a graph drawing.
  """

  def height_fn(opts \\ []) do
    fn
      {:l, _, _} -> Keyword.get(opts, :header, 26)
      {:r, _, _} -> Keyword.get(opts, :footer, 10)
      {_, _, _} -> 0
      {_, _} -> 0
      _id -> Keyword.get(opts, :leaf, 22)
    end
  end

  def width_fn(opts \\ []) do
    fn
      {:l, _, _} -> 0
      {:r, _, _} -> 0
      {_, :-} -> Keyword.get(opts, :left, 0)
      {_, :+} -> Keyword.get(opts, :right, 0)
      {_, _, n} when is_integer(n) -> 0
      _leaf -> Keyword.get(opts, :leaf, 200)
    end
  end
end
