defmodule Graph.RangeMap do
  @moduledoc """
  This module implements a counting accumulator for ranges which can be used in
  a greedy algorithm for the hitting set problem (i.e. returning a set of elements
  which intersects every range).
  """

  @type t :: %__MODULE__{ranges: MapSet.t(), counts: frequency}
  @typep frequency :: %{optional(integer) => pos_integer}
  @typep range :: Range.t() | singleton_range
  @typep singleton_range :: integer

  defstruct ranges: MapSet.new(), counts: %{}

  @doc "Returns an empty range map"
  @spec new :: t
  def new, do: %__MODULE__{}

  @doc "Returns a range map accumulating a collection of ranges"
  @spec new([range]) :: t
  def new([_ | _] = ranges) do
    Enum.reduce(ranges, new(), &put(&2, &1))
  end

  @doc "Accumulates a range"
  @spec put(t, range) :: t
  def put(range_map, range)

  def put(%__MODULE__{ranges: rs, counts: cs} = range_map, _.._ = range) do
    if MapSet.member?(rs, range) do
      range_map
    else
      %{
        range_map
        | counts: Enum.reduce(range, cs, &Map.update(&2, &1, 1, fn c -> c + 1 end)),
          ranges: MapSet.put(rs, range)
      }
    end
  end

  # Accumulates a singleton range
  def put(%__MODULE__{} = range_map, k) when is_integer(k) do
    put(range_map, k..k)
  end

  @doc "Pops an element from the range map"
  @spec pop(t, integer) :: t
  def pop(%__MODULE__{ranges: rs, counts: cs}, k) do
    ranges =
      rs
      |> Enum.filter(&Enum.member?(&1, k))
      |> MapSet.new()

    cs =
      ranges
      |> Enum.flat_map(& &1)
      |> Enum.reduce(cs, &Map.update!(&2, &1, fn c -> c - 1 end))
      |> Enum.reject(fn {_, c} -> c == 0 end)
      |> Map.new()

    %__MODULE__{ranges: MapSet.difference(rs, ranges), counts: cs}
  end

  @doc "Returns the most frequent element"
  @spec max(t) :: integer
  def max(%__MODULE__{counts: cs}) do
    cs
    |> Enum.max_by(fn {_, n} -> n end)
    |> elem(0)
  end

  @doc "Returns a greedy set covering all ranges in the accumulator"
  @spec greedy_cover(t) :: [integer]
  def greedy_cover(range_map)

  def greedy_cover(%__MODULE__{counts: counts}) when map_size(counts) == 0, do: []

  def greedy_cover(%__MODULE__{} = range_map) do
    case pop_max(range_map) do
      {max, range_map} -> [max | greedy_cover(range_map)]
    end
  end

  @doc "Returns the most frequent element and a range map excluding that element"
  @spec pop_max(t) :: {integer, t}
  def pop_max(%__MODULE__{} = range_map) do
    max = max(range_map)
    range_map = pop(range_map, max)
    {max, range_map}
  end

  def union(%__MODULE__{} = rm, %__MODULE__{ranges: ranges}) do
    Enum.reduce(ranges, rm, &put(&2, &1))
  end

  def span(%__MODULE__{counts: counts} = _rm) do
    {min, max} =
      counts
      |> Map.keys()
      |> Enum.min_max()

    min..max
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Graph.RangeMap{ranges: rs}, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["#RangeMap<", Inspect.List.inspect(MapSet.to_list(rs), opts), ">"])
    end
  end
end
