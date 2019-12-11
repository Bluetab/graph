defmodule Graph.NestingGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.NestingGraph

  describe "Graph.NestingGraph" do
    @tag vertices: [:a, :b, :c, :d, 1, 2, 3, 4]
    @tag tree: [a: [b: [1, 2], c: [d: [3, 4]]]]
    @tag edges: [{1, 2}, {:b, 1}, {:c, 1}, {3, :c}, {4, :b}, {:c, :d}, {:b, :a}, {:d, :b}, {2, 3}]
    test "includes border nodes, connectivity edges, cycles and ranks", %{g: g, t: t} do
      ng = NestingGraph.new(g, t)

      # TODO: cycles: [{2, 1}]

      assert %ClusteredLevelGraph{g: %{g: g}} = ng

      assert Graph.vertices(g) == [
               1,
               2,
               3,
               4,
               {:a, :+},
               {:a, :-},
               {:b, :+},
               {:b, :-},
               {:c, :+},
               {:c, :-},
               {:d, :+},
               {:d, :-}
             ]

      assert Graph.out_neighbours(g, {:a, :-}) == []
      assert Graph.out_neighbours(g, {:b, :-}) == [1, {:d, :+}]
      assert Graph.out_neighbours(g, {:c, :-}) == [{:d, :-}]
      assert Graph.out_neighbours(g, {:d, :-}) == []
      assert Graph.out_neighbours(g, {:a, :+}) == []
      assert Graph.out_neighbours(g, {:b, :+}) == [{:a, :+}]
      assert Graph.out_neighbours(g, {:c, :+}) == []
      assert Graph.out_neighbours(g, {:d, :+}) == []
      assert Graph.out_neighbours(g, 1) == [2, {:c, :+}]
      assert Graph.out_neighbours(g, 2) == [3]
      assert Graph.out_neighbours(g, 3) == [{:c, :+}]
      assert Graph.out_neighbours(g, 4) == [{:b, :-}]

      %{
        1 => 6,
        2 => 7,
        3 => 9,
        4 => 4,
        {:a, :+} => 12,
        {:a, :-} => 1,
        {:b, :+} => 8,
        {:b, :-} => 5,
        {:c, :+} => 11,
        {:c, :-} => 2,
        {:d, :+} => 10,
        {:d, :-} => 3
      }
      |> Enum.each(fn {v, r} ->
        assert %{r: rank} = Graph.vertex_label(g, v)
        assert rank == r, "Vertex #{inspect(v)} has rank #{rank}, expected #{r}"
      end)
    end
  end
end
