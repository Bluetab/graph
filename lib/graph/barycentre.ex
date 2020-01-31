defmodule Graph.Barycentre do
  @moduledoc """
  The barycentre measure of a vertex is calculated as the average "position" of
  it's predecessors in the graph.
  """

  alias Graph.Vertex

  @doc """
  Returns a function which takes a vertex and returns it's barycentre in the
  graph `g`. By default, a vertex's label ':b' is used to determine it's
  position in a layer. The `pos_fn` function may be used to specify an different
  criteria.
  """
  @spec b(Graph.t(), (Graph.t(), Vertex.id() -> pos_integer)) :: (Vertex.id() -> float)
  def b(%Graph{} = g, pos_fn \\ &default_position_fn/2) do
    fn v ->
      case Graph.in_degree(g, v) do
        0 ->
          # Logger.debug("Vertex #{inspect(v)} has degree 0")
          pos_fn.(g, v)

        d when is_integer(d) ->
          b =
            g
            |> Graph.in_neighbours(v)
            |> Enum.map(&pos_fn.(g, &1))
            |> Enum.sum()

          b / d
      end
    end
  end

  defp default_position_fn(%Graph{} = g, v) do
    case Graph.vertex(g, v, :b) do
      nil -> :random.uniform(50)
      b -> b
    end
  end
end
