defmodule Graph.ClusteredCrossingReductionTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredCrossingReduction
  alias Graph.ClusteredLevelGraph
  alias Graph.LevelGraph

  @levels [
    [
      {:l, :c2, 1},
      1,
      2,
      {:r, :c2, 1},
      3,
      {:l, :c3, 1},
      4,
      {:l, :c5, 1},
      5,
      {:r, :c5, 1},
      {:r, :c3, 1}
    ],
    [
      {:l, :c2, 2},
      :a,
      :b,
      :c,
      :d,
      {:r, :c2, 2},
      :e,
      :f,
      {:l, :c3, 2},
      :g,
      :h,
      {:l, :c5, 2},
      :i,
      {:r, :c5, 2},
      :j,
      {:r, :c3, 2}
    ]
  ]
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
    {5, :j},
    {{:l, :c2, 1}, {:l, :c2, 2}},
    {{:l, :c3, 1}, {:l, :c3, 2}},
    {{:l, :c5, 1}, {:l, :c5, 2}},
    {{:r, :c2, 1}, {:r, :c2, 2}},
    {{:r, :c3, 1}, {:r, :c3, 2}},
    {{:r, :c5, 1}, {:r, :c5, 2}}
  ]
  @tree [
    c1: [
      3,
      :e,
      :f,
      c2: [{:l, :c2, 1}, {:r, :c2, 1}, {:l, :c2, 2}, {:r, :c2, 2}, 1, 2, :c, :d, c4: [:a, :b]],
      c3: [
        {:l, :c3, 1},
        {:r, :c3, 1},
        {:l, :c3, 2},
        {:r, :c3, 2},
        4,
        :g,
        :h,
        :j,
        c5: [{:l, :c5, 1}, {:r, :c5, 1}, {:l, :c5, 2}, {:r, :c5, 2}, 5, :i]
      ]
    ]
  ]

  describe "Graph.ClusteredCrossingReduction" do
    @tag vertices:
           @levels
           |> Enum.flat_map(&Enum.with_index/1)
           |> Map.new(fn {v, b} -> {v, %{b: b + 1}} end)
    @tag edges: @edges
    @tag tree: @tree
    test "foo", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert ClusteredCrossingReduction.permute(clg) == [
               {:l, :c2, 2},
               :a,
               :b,
               :c,
               :d,
               {:r, :c2, 2},
               :e,
               :f,
               {:l, :c3, 2},
               :g,
               :h,
               {:l, :c5, 2},
               :i,
               {:r, :c5, 2},
               :j,
               {:r, :c3, 2}
             ]
    end

    @tag vertices:
           @levels
           |> Enum.flat_map(&Enum.with_index/1)
           |> Map.new(fn {v, b} -> {v, %{b: b + 1}} end)
    @tag edges: @edges
    @tag tree: @tree
    test "bar", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert ClusteredCrossingReduction.permute(clg, 2, 1) == [
               {:l, :c2, 1},
               1,
               2,
               {:r, :c2, 1},
               3,
               {:l, :c3, 1},
               4,
               {:l, :c5, 1},
               5,
               {:r, :c5, 1},
               {:r, :c3, 1}
             ]
    end
  end
end
