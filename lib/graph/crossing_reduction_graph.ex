defmodule Graph.CrossingReductionGraph do
  @moduledoc """
  A crossing reduction graph as described in Forster, M. (2005). This
  implementation support constraints.
  """
  alias Graph.LevelGraph

  @type constraint_graph :: Graph.t()
  @type t :: %__MODULE__{g: LevelGraph.t(), gc: constraint_graph}

  defstruct g: %LevelGraph{}, gc: %Graph{}

  @doc """
  Return a new crossing reduction graph consisting of a 2-level graph `g` and
  it's constraint graph `gc`.
  """
  @spec new(LevelGraph.t(), constraint_graph) :: t
  def new(%LevelGraph{} = g, %Graph{} = gc) do
    %__MODULE__{g: g, gc: gc}
  end
end
