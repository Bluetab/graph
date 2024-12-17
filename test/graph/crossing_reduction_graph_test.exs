defmodule Graph.CrossingReductionGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.CrossingReduction
  alias Graph.LevelGraph

  @vertices [[1, 2, 3, 4, 5], [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j]]
            |> Enum.flat_map(&Enum.with_index(&1, 1))
            |> Enum.map(fn {v, b} -> {v, %{b: b}} end)
            |> Map.new()
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
    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "new/2 returns a new clustered level graph, clusters have span", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert %{c1: c1, c2: c2, c3: c3, c4: c4, c5: c5} =
               CrossingReduction.crossing_reduction_graphs(clg, :down)

      assert edges(c1) |||
               [
                 {1, :c2},
                 {1, :c2},
                 {2, :c2},
                 {2, :c2},
                 {2, :c2},
                 {2, :f},
                 {3, :c2},
                 {3, :e},
                 {4, :c3},
                 {4, :c3},
                 {4, :c3},
                 {4, :f},
                 {5, :c3}
               ]

      assert edges(c2) ||| [{1, :c4}, {1, :c4}, {2, :c}, {2, :c4}, {2, :d}, {3, :d}]
      assert edges(c3) ||| [{4, :c5}, {4, :g}, {4, :h}, {5, :j}]
      assert edges(c4) ||| [{1, :a}, {1, :b}, {2, :b}]
      assert edges(c5) ||| [{4, :i}]
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "new/2 with free level before fixed level", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert %{c1: c1, c2: c2, c3: c3, c5: c5} =
               CrossingReduction.crossing_reduction_graphs(clg, :up)

      assert edges(c1) |||
               [
                 a: :c2,
                 b: :c2,
                 b: :c2,
                 c: :c2,
                 d: 3,
                 d: :c2,
                 e: 3,
                 f: :c2,
                 f: :c3,
                 g: :c3,
                 h: :c3,
                 i: :c3,
                 j: :c3
               ]

      assert edges(c2) ||| [a: 1, b: 1, b: 2, c: 2, d: 2, f: 2]
      assert edges(c3) ||| [f: 4, g: 4, h: 4, i: 4, j: :c5]
      assert edges(c5) ||| [j: 5]
    end
  end
end
