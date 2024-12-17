defmodule TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  def a <~> b, do: approximately_equal(a, b)
  def a ||| b, do: approximately_equal(Enum.sort(a), Enum.sort(b))

  defp approximately_equal([h | t], [h2 | t2]) do
    approximately_equal(h, h2) && approximately_equal(t, t2)
  end

  defp approximately_equal(a, b), do: a == b
end
