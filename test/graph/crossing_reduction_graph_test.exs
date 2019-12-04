defmodule Graph.CrossingReductionGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.CrossingReductionGraph
  alias Graph.LevelGraph

  describe "Graph.CrossingReductionGraph" do
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
           root: [
             1,
             2,
             3,
             4,
             5,
             c1: [:e, :f, c2: [:c, :d, c4: [:a, :b]], c3: [:g, :h, :j, c5: [:i]]]
           ]
         ]
    test "new/2 returns a new clustered level graph, clusters have span", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert crg = CrossingReductionGraph.new(clg, :root, 2)
      assert %{sub: %{c1: c1}} = crg

      assert edges(c1) == [
               {1, :c2, 2},
               {2, :c2, 3},
               {2, :f, 1},
               {3, :c2, 1},
               {3, :e, 1},
               {4, :c3, 3},
               {4, :f, 1},
               {5, :c3, 1}
             ]

      assert %{sub: %{c2: c2, c3: c3}} = c1

      assert edges(c2) == [{1, :c4, 2}, {2, :c, 1}, {2, :c4, 1}, {2, :d, 1}, {3, :d, 1}]
      assert edges(c3) == [{4, :c5, 1}, {4, :g, 1}, {4, :h, 1}, {5, :j, 1}]
      assert %{sub: %{c4: c4}} = c2
      assert edges(c4) == [{1, :a, 1}, {1, :b, 1}, {2, :b, 1}]
      assert %{sub: %{c5: c5}} = c3
      assert edges(c5) == [{4, :i, 1}]
    end
  end
end
