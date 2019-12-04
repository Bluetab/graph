defmodule Graph.ClusteredLevelGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.ClusterTree
  alias Graph.LevelGraph
  alias Graph.Traversal

  describe "Graph.ClusteredLevelGraph" do
    @tag edges: [{11, 21}, {12, 22}, {13, 21}, {14, 23}]
    @tag tree: [root: [a: [11, 21, b: [13, c: [14]]], d: [12, 22], e: [23]]]
    test "new/2 returns a new clustered level graph, clusters have span", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert ClusteredLevelGraph.span(clg, :root) == {1, 2}
      assert ClusteredLevelGraph.span(clg, :a) == {1, 2}
      assert ClusteredLevelGraph.span(clg, :b) == {1, 1}
      assert ClusteredLevelGraph.span(clg, :c) == {1, 1}
      assert ClusteredLevelGraph.span(clg, :d) == {1, 2}
      assert ClusteredLevelGraph.span(clg, :e) == {2, 2}

      assert LevelGraph.is_proper?(lg)
      assert ClusteredLevelGraph.is_proper?(clg)
    end

    @tag edges: [{1, 3}, {2, 4}]
    @tag tree: [a: [1, b: [2, c: [3, 4]]]]
    test "level_cluster_trees/1", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert clg = ClusteredLevelGraph.new(lg, t)

      assert %{1 => t1, 2 => t2} = ClusteredLevelGraph.level_cluster_trees(clg)
      assert Graph.vertices(t1) == [1, 2, :a, :b]
      assert Graph.vertices(t2) == [3, 4, :a, :b, :c]

      assert %{1 => t1, 2 => t2} = ClusteredLevelGraph.level_cluster_trees(clg, contracted: true)
      assert Graph.vertices(t1) == [1, 2, :a]
      assert Graph.vertices(t2) == [3, 4, :c]
    end

    @tag edges: [{4, :i}]
    @tag tree: [root: [4, c1: [c3: [c5: [:i]]]]]
    test "level_cluster_trees/2 c5 issue", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)
      assert LevelGraph.level(lg, :i) == 2

      sg =
        t
        |> Traversal.reaching_subgraph([:i])
        |> ClusterTree.contracted()

      assert Graph.vertices(sg) == [:i]
    end
  end
end
