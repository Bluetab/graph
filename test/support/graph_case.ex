defmodule GraphCase do
  @moduledoc """
  This module defines the setup for tests requiring graph fixtures.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case

      import TestOperators

      setup tags do
        g =
          case tags[:vertices] do
            nil -> Graph.new()
            vs -> Graph.new(vs)
          end

        g =
          case tags[:edges] do
            nil ->
              g

            edges ->
              Enum.reduce(edges, g, fn {v1, v2}, g ->
                g
                |> Graph.add_vertex(v1)
                |> Graph.add_vertex(v2)
                |> Graph.add_edge(v1, v2)
              end)
          end

        %{g: g}
      end

      defp edges(%Graph.LevelGraph{g: g}) do
        edges(g)
      end

      defp edges(%Graph.CrossingReductionGraph{g: g}) do
        edges(g)
      end

      defp edges(%Graph{} = g) do
        g
        |> Graph.get_edges(fn {_, {v1, v2, _}} -> {v1, v2} end)
        |> Enum.sort()
      end

      defp out_neighbours(%Graph{} = g, v) do
        g
        |> Graph.out_neighbours(v)
        |> Enum.sort()
      end
    end
  end
end
