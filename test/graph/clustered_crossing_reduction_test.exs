defmodule Graph.ClusteredCrossingReductionTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredCrossingReduction
  alias Graph.ClusteredLevelGraph
  alias Graph.LevelGraph

  @order [
    {:l, :c2},
    1,
    2,
    {:r, :c2},
    3,
    {:l, :c1},
    {:l, :c3},
    4,
    {:l, :c5},
    5,
    {:r, :c5},
    {:r, :c3},
    {:r, :c1}
  ]

  describe "Graph.ClusteredCrossingReduction" do
    @tag vertices: Enum.with_index(@order) |> Map.new(fn {v, b} -> {v, %{b: b + 1}} end)
    @tag edges: [
           {1, :a},
           {1, :b},
           {2, :b},
           {2, :c},
           {2, :d},
           {2, :f},
           {3, :d},
           {3, :e},
           {4, :f},
           {4, :g},
           {4, :h},
           {4, :i},
           {5, :j}
         ]
    @tag tree: [
           c1: [
             {:l, :c1},
             {:r, :c1},
             3,
             :e,
             :f,
             c2: [{:l, :c2}, {:r, :c2}, 1, 2, :c, :d, c4: [:a, :b]],
             c3: [{:l, :c3}, {:r, :c3}, 4, :g, :h, :j, c5: [{:l, :c5}, {:r, :c5}, 5, :i]]
           ]
         ]
    test "bar", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert ClusteredCrossingReduction.permute(clg) == [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j]
    end
  end
end
