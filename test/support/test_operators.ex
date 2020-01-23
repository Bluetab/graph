defmodule TestOperators do
  @moduledoc """
  Equality operators for tests
  """

  def a <~> b, do: Enum.sort(a) == Enum.sort(b)
end
