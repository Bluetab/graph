defmodule TreeCase do
  @moduledoc """
  This module defines the setup for tests requiring tree fixtures.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case

      import TestOperators

      setup tags do
        case tags[:tree] do
          nil -> :ok
          t -> [t: Enum.reduce(t, Graph.new(), &add_node/2)]
        end
      end

      defp add_node({parent, children} = n, %Graph{} = g) when is_list(children) do
        Enum.reduce(children, Graph.add_vertex(g, parent), fn c, g ->
          c
          |> add_node(g)
          |> add_edge(parent, c)
        end)
      end

      defp add_node({n, %{} = label}, %Graph{} = g), do: Graph.add_vertex(g, n, label)
      defp add_node(n, %Graph{} = g), do: Graph.add_vertex(g, n)

      defp add_edge(g, parent, {child, grandchildren}) when is_list(grandchildren),
        do: Graph.add_edge(g, parent, child)

      defp add_edge(g, parent, child), do: Graph.add_edge(g, parent, child)
    end
  end
end
