defmodule Graph.CoordinateAssignment do
  @moduledoc """
  Coordinate assignment based on Brandes and Köpf (2002), "Fast and Simple
  Horizontal Coordinate Assignment".
  """
  alias Graph.LevelGraph
  alias Graph.Vertex

  @spec type1_conflicts(LevelGraph.t()) :: [{Vertex.id(), Vertex.id()}]
  def type1_conflicts(%LevelGraph{g: g} = lg) do
    lg
    |> LevelGraph.vertices_by_level()
    |> Enum.sort()
    |> Enum.drop(1)
    |> Enum.map(fn {_level, vs} -> Enum.sort_by(vs, &Graph.vertex(g, &1, :b)) end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(&do_type1_conflicts(&1, g))
  end

  @spec do_type1_conflicts([[Vertex.id()]], Graph.t()) :: [{Vertex.id(), Vertex.id()}]
  defp do_type1_conflicts([us, vs], %Graph{} = g) do
    vs_count = Enum.count(vs)

    vs
    |> Enum.sort_by(&Graph.vertex(g, &1, :b))
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{k0: 0, l: 1, conflicts: []},
      fn {v, l1}, %{k0: k0, l: l, conflicts: conflicts} = acc ->
        case k1(l1, vs_count, us, g, v) do
          nil ->
            acc

          k1 ->
            uvs =
              vs
              |> Enum.slice(l - 1, l1 - l)
              |> Enum.map(&{&1, Graph.in_neighbours(g, &1)})
              |> Enum.flat_map(fn {v, us} -> Enum.map(us, &{&1, v}) end)
              |> Enum.group_by(fn {u, _v} -> Graph.vertex(g, u, :b) end)
              |> Enum.filter(fn {k, _uvs} -> k < k0 or k > k1 end)
              |> Enum.flat_map(fn {_k, uvs} -> uvs end)

            %{acc | k0: k1, l: l1 + 1, conflicts: conflicts ++ uvs}
        end
      end
    )
    |> Map.get(:conflicts)
  end

  @spec k1(pos_integer, pos_integer, [Vertex.id()], Graph.t(), Vertex.id()) :: pos_integer | nil
  defp k1(l1, lmax, us, g, v)

  defp k1(l1, l1, us, _g, _v), do: Enum.count(us)

  defp k1(_, _, _, g, v) do
    if Graph.vertex(g, v, :dummy) do
      g
      |> Graph.in_neighbours(v)
      |> Enum.filter(&Graph.vertex(g, &1, :dummy))
      |> Enum.map(&Graph.vertex(g, &1, :b))
      |> Enum.find(& &1)
    end
  end
end
