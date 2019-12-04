defmodule GraphCase do
  @moduledoc """
  This module defines the setup for tests requiring graph fixtures.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case

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

      defp edges(%Graph.CrossingReductionGraph{g: g}) do
        g
        |> Graph.get_edges()
        |> Enum.map(fn %{label: %{w: w}, v1: v1, v2: v2} -> {v1, v2, w} end)
        |> Enum.group_by(fn {v1, v2, _} -> {v1, v2} end, &elem(&1, 2))
        |> Enum.map(fn {{v1, v2}, ws} -> {v1, v2, Enum.sum(ws)} end)
        |> Enum.sort()
      end

      defp barycenter_fn(%Graph{} = g) do
        fn v ->
          case Graph.in_degree(g, v) do
            {:error, _} ->
              raise(ArgumentError, "Missing vertex")

            0 ->
              1

            d ->
              b =
                g
                |> Graph.in_neighbours(v)
                |> Enum.map(&Graph.vertex(g, &1, :b))
                |> Enum.sum()

              b / d
          end
        end
      end
    end
  end
end
