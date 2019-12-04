defmodule Graph.Vertex do
  @moduledoc """
  Represents a vertex in a graph.
  """

  defstruct [:id, label: %{}]

  @type id :: any
  @type label :: map
  @type t :: %__MODULE__{id: id, label: label}
end
