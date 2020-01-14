defmodule Graph.RangeMapTest do
  use ExUnit.Case

  alias Graph.RangeMap

  describe "Range Map" do
    test "accumulates counts for each range element" do
      assert %RangeMap{counts: counts} = RangeMap.new([1..9, 2..4, 4, 6..9, 7..8])
      assert counts == %{1 => 1, 2 => 2, 3 => 2, 4 => 3, 5 => 1, 6 => 2, 7 => 3, 8 => 3, 9 => 2}
    end

    test "returns the maximum element" do
      assert %RangeMap{} = rm = RangeMap.new([1..9, 2..4, 4, 6..9, 7..8])
      assert RangeMap.max(rm) == 4
    end

    test "pops the most frequent element" do
      assert %RangeMap{} = rm = RangeMap.new([1..9, 2..4, 4, 6..9, 7..8])
      assert {4, rm2} = RangeMap.pop_max(rm)
      assert rm2 == RangeMap.new([6..9, 7..8])
      assert {7, RangeMap.new()} == RangeMap.pop_max(rm2)
    end

    test "returns the greedy covering set" do
      assert %RangeMap{} = rm = RangeMap.new([1..9, 2..4, 4, 6..9, 7..8])
      assert RangeMap.greedy_cover(rm) == [4, 7]
    end
  end
end
