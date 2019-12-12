defmodule Graph.EdgeRoutingTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.LevelGraph
  alias Graph.EdgeRouting
  alias Graph.NestingGraph

  describe "Edge Routing" do
    @tag vertices: [:root, :a, :b, :a1, :a2, :b1, :b2, 1, 2, 3, 4]
    @tag edges: [{1, 2}, {2, 3}, {3, 4}, {1, 4}]
    @tag tree: [root: [a: [a1: [1], a2: [2]], b: [b1: [3], b2: [4]]]]
    test "routes long span edges mostly inside border rectangles", %{g: g, t: t} do
      clg = NestingGraph.new(g, t)
      assert %ClusteredLevelGraph{} = clg
      assert LevelGraph.level(clg.g, 1) == 4
      assert LevelGraph.level(clg.g, 4) == 15

      assert EdgeRouting.edge_routing(clg, 1, 4, :root) == %{
               5 => :a1,
               6 => :a,
               7 => :a,
               8 => :a,
               9 => :a,
               10 => :b,
               11 => :b,
               12 => :b,
               13 => :b,
               14 => :b2
             }
    end
  end
end
