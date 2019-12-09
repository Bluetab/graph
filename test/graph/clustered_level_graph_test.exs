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

    @tag edges: [{11, 21}, {12, 22}, {13, 21}, {14, 23}]
    @tag tree: [root: [a: [11, 21, b: [13, c: [14]]], d: [12, 22], e: [23]]]
    test "insert_border_segments/1", %{g: g, t: t} do
      assert lg = LevelGraph.new(g)

      assert %{g: %{g: g}, t: t} =
               lg
               |> ClusteredLevelGraph.new(t)
               |> ClusteredLevelGraph.insert_border_segments()

      Enum.each(
        %{
          root: [{:l, :root, 1}, {:r, :root, 1}, {:l, :root, 2}, {:r, :root, 2}],
          a: [{:l, :a, 1}, {:r, :a, 1}, {:l, :a, 2}, {:r, :a, 2}],
          b: [{:l, :b, 1}, {:r, :b, 1}],
          c: [{:l, :c, 1}, {:r, :c, 1}],
          d: [{:l, :d, 1}, {:r, :d, 1}, {:l, :d, 2}, {:r, :d, 2}],
          e: [{:l, :e, 2}, {:r, :e, 2}]
        },
        fn {v, ws} ->
          out_neighbours = Graph.out_neighbours(t, v)
          assert Enum.all?(ws, &Enum.member?(out_neighbours, &1))
        end
      )

      assert Graph.source_vertices(g) == [
               11,
               12,
               13,
               14,
               {:l, :a, 1},
               {:l, :b, 1},
               {:l, :c, 1},
               {:l, :d, 1},
               {:l, :e, 2},
               {:l, :root, 1},
               {:r, :a, 1},
               {:r, :b, 1},
               {:r, :c, 1},
               {:r, :d, 1},
               {:r, :e, 2},
               {:r, :root, 1}
             ]

      assert Graph.sink_vertices(g) == [
               21,
               22,
               23,
               {:l, :a, 2},
               {:l, :b, 1},
               {:l, :c, 1},
               {:l, :d, 2},
               {:l, :e, 2},
               {:l, :root, 2},
               {:r, :a, 2},
               {:r, :b, 1},
               {:r, :c, 1},
               {:r, :d, 2},
               {:r, :e, 2},
               {:r, :root, 2}
             ]
    end
  end
end
