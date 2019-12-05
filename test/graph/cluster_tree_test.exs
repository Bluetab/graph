defmodule Graph.ClusterTreeTest do
  use GraphCase

  alias Graph.ClusterTree
  alias Graph.Edge
  alias Graph.Traversal

  doctest Graph.ClusterTree

  describe "Graph.ClusterTree" do
    @tag vertices: [:a, :b, :c, 1, 2, 3, 4]
    @tag edges: [a: 1, a: :b, b: 2, b: :c, c: 3, c: 4]
    test "contracted/1 returns a contracted level cluster tree", %{g: t} do
      assert [t1, t2] =
               [[1, 2], [3, 4]]
               |> Enum.map(&Traversal.reaching_subgraph(t, &1))
               |> Enum.map(&ClusterTree.contracted/1)

      assert Graph.vertices(t1) == [1, 2, :a]
      assert Graph.vertices(t2) == [3, 4, :c]
      assert Graph.get_edges(t1, &Edge.entry_pair/1) == [a: 1, a: 2]
      assert Graph.get_edges(t2, &Edge.entry_pair/1) == [c: 3, c: 4]
    end
  end
end