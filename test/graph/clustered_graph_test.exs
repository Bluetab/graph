defmodule Graph.ClusteredGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredGraph

  describe "Graph.ClusteredGraph" do
    @tag vertices: [:c1, :c2, :c3, :c4, :c5, :root]
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
    test "new/1", %{g: g, t: t} do
      cg = ClusteredGraph.new(g, t)
      assert cg
    end
  end
end
