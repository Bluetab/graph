defmodule Graph.Edge do
  @moduledoc """
  Represents an edge (v1, v2) from vertex v1 to v2 in a graph.
  """

  alias Graph.Vertex

  defstruct [:id, :v1, :v2, label: %{}]

  @type id :: any
  @type label :: map
  @type t :: %__MODULE__{id: id, v1: Vertex.id(), v2: Vertex.id(), label: label}

  @spec from_entry({id, {Vertex.id(), Vertex.id(), label}}) :: t
  def from_entry({id, {v1, v2, label}}), do: %__MODULE__{id: id, v1: v1, v2: v2, label: label}

  @spec entry_pair({id, {Vertex.id(), Vertex.id(), label}}) :: {Vertex.id(), Vertex.id()}
  def entry_pair({_, {v1, v2, _}}), do: {v1, v2}
end
