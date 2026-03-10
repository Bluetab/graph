defmodule Bluetab.GraphCase do
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
            nil -> Bluetab.Graph.new()
            vs -> Bluetab.Graph.new(vs)
          end

        g =
          case tags[:edges] do
            nil ->
              g

            edges ->
              Enum.reduce(edges, g, fn {v1, v2}, g ->
                g
                |> Bluetab.Graph.add_vertex(v1)
                |> Bluetab.Graph.add_vertex(v2)
                |> Bluetab.Graph.add_edge(v1, v2)
              end)
          end

        %{g: g}
      end

      defp edges(%Bluetab.Graph.LevelGraph{g: g}) do
        edges(g)
      end

      defp edges(%Bluetab.Graph.CrossingReductionGraph{g: g}) do
        edges(g)
      end

      defp edges(%Bluetab.Graph{} = g) do
        g
        |> Bluetab.Graph.get_edges(fn {_, {v1, v2, _}} -> {v1, v2} end)
        |> Enum.sort()
      end

      defp out_neighbours(%Bluetab.Graph{} = g, v) do
        g
        |> Bluetab.Graph.out_neighbours(v)
        |> Enum.sort()
      end
    end
  end
end
