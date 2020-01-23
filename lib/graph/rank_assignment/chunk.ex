defmodule Graph.RankAssignment.Chunk do
  def chunk([_ | _] = rs) do
    rs
    |> flatten()
    |> Enum.sort()
    |> Enum.uniq()
    |> Enum.chunk_while(
      [],
      fn
        r, [] -> {:cont, [r]}
        r, [prev | _] = rs when prev == r - 1 -> {:cont, [r | rs]}
        r, rs -> {:cont, range(rs), [r]}
      end,
      fn
        [] -> {:cont, []}
        rs -> {:cont, range(rs), []}
      end
    )
  end

  defp range([_ | _] = rs) do
    case Enum.min_max(rs) do
      {min, max} -> min..max
    end
  end

  defp flatten([_ | _] = rs), do: Enum.flat_map(rs, &flatten/1)
  defp flatten(_.._ = r), do: Enum.map(r, & &1)
  defp flatten(r), do: [r]
end
