defmodule Graph.RankAssignmentTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.LevelGraph
  alias Graph.RankAssignment

  describe "Rank Assignment" do
    @tag edges: [a: :b, a: :e, b: :c, c: :d, e: :d, d: :a]
    test "returns an acyclic graph with a valid rank assignment and inverted edges", %{g: g} do
      assert %Graph{} = g = RankAssignment.assign_rank(g, [:a])
      assert Graph.acyclic?(g)
      assert out_neighbours(g, :a) ||| [:b, :d, :e]
      assert out_neighbours(g, :e) ||| [:d]

      lg = LevelGraph.new(g, :r_min)
      assert LevelGraph.vertices_by_level(lg) == %{1 => [:a], 2 => [:b, :e], 3 => [:c], 4 => [:d]}

      lg = LevelGraph.new(g, :r_max)
      assert LevelGraph.vertices_by_level(lg) == %{1 => [:a], 2 => [:b], 3 => [:c, :e], 4 => [:d]}
    end

    @tag tree: [root: [g1: [:a, :b, :d], g2: [:c, :e]]]
    @tag edges: [a: :b, a: :e, b: :c, c: :d, e: :d, d: :a]
    test "assigns cluster ranks greedily", %{g: g, t: t} do
      assert %ClusteredLevelGraph{g: %{g: g} = _lg, t: t} = RankAssignment.assign_rank(g, t, [:a])

      assert %{b: _b, r: 7, r_max: 3, r_min: 2} = Graph.vertex_label(g, :e)

      assert Graph.vertex(t, :root, :rs) ||| [3, 1, 2, 4]
      assert Graph.vertex(t, :g2, :rs) ||| [3]

      assert Graph.vertex(t, :root, :r) ||| [1..4]
      assert Graph.vertex(t, {:g1, 1..2}, :r) == 1..2
      assert Graph.vertex(t, {:g1, 4..4}, :r) == 4..4
      assert Graph.vertex(t, :e, :r) == 3
    end
  end
end
