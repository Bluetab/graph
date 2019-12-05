defmodule Graph.CrossingReductionGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.CrossingReductionGraph
  alias Graph.LevelGraph

  @edges [
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
  @tree [c1: [3, :e, :f, c2: [1, 2, :c, :d, c4: [:a, :b]], c3: [4, :g, :h, :j, c5: [5, :i]]]]

  describe "Graph.CrossingReductionGraph" do
    @tag edges: @edges
    @tag tree: @tree
    test "new/2 returns a new clustered level graph, clusters have span", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert crg = CrossingReductionGraph.new(clg, :c1, 1, 2)
      assert %{g: c1, sub: %{c2: c2, c3: c3}} = crg

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

      assert edges(c2) == [{1, :c4, 2}, {2, :c, 1}, {2, :c4, 1}, {2, :d, 1}, {3, :d, 1}]
      assert edges(c3) == [{4, :c5, 1}, {4, :g, 1}, {4, :h, 1}, {5, :j, 1}]
      assert %{sub: %{c4: c4}} = c2
      assert edges(c4) == [{1, :a, 1}, {1, :b, 1}, {2, :b, 1}]
      assert %{sub: %{c5: c5}} = c3
      assert edges(c5) == [{4, :i, 1}]
    end

    @tag edges: @edges
    @tag tree: @tree
    test "new/2 with free level before fixed level", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert crg = CrossingReductionGraph.new(clg, :c1, 2, 1)
      assert %{g: c1, sub: %{c2: c2, c3: c3}} = crg

      assert edges(c1) == [
               {:a, :c2, 1},
               {:b, :c2, 2},
               {:c, :c2, 1},
               {:d, 3, 1},
               {:d, :c2, 1},
               {:e, 3, 1},
               {:f, :c2, 1},
               {:f, :c3, 1},
               {:g, :c3, 1},
               {:h, :c3, 1},
               {:i, :c3, 1},
               {:j, :c3, 1}
             ]

      assert edges(c2) == [{:a, 1, 1}, {:b, 1, 1}, {:b, 2, 1}, {:c, 2, 1}, {:d, 2, 1}, {:f, 2, 1}]
      assert edges(c3) == [{:f, 4, 1}, {:g, 4, 1}, {:h, 4, 1}, {:i, 4, 1}, {:j, :c5, 1}]
      assert %{sub: %{c5: c5}} = c3
      assert edges(c5) == [{:j, 5, 1}]
    end
  end
end
