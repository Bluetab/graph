defmodule Graph.NestingGraphTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.NestingGraph

  describe "Graph.NestingGraph" do
    @tag vertices: [:a, :b, :c, :d, 1, 2, 3, 4]
    @tag tree: [a: [b: [1, 2], c: [d: [3, 4]]]]
    @tag edges: [{1, 2}, {:b, 1}, {:c, 1}, {3, :c}, {4, :b}, {:c, :d}, {:b, :a}, {:d, :b}, {2, 3}]
    test "includes border nodes, connectivity edges, ranks and inverted edges", %{g: g, t: t} do
      ng = NestingGraph.new(g, t)

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
      assert Graph.out_neighbours(g, {:b, :-}) == [1]
      assert Graph.out_neighbours(g, {:c, :-}) == [{:d, :-}]
      assert Graph.out_neighbours(g, {:d, :-}) == []
      assert Graph.out_neighbours(g, {:a, :+}) == []
      assert Graph.out_neighbours(g, {:b, :+}) == [{:a, :+}, {:d, :+}]
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

      inverted_edges =
        g
        |> Graph.get_edges()
        |> Enum.filter(fn %{label: l} -> l[:inverted] end)
        |> Enum.map(fn %{v1: v1, v2: v2} -> {v1, v2} end)

      assert inverted_edges == [{1, {:c, :+}}]
    end

    @tag vertices: [:root, :a, :b, :a1, :a2, :b1, :b2, 1, 2, 3, 4]
    @tag edges: [{1, 2}, {2, 3}, {3, 4}, {1, 4}, {:b2, :a2}]
    @tag tree: [root: [a: [a1: [1], a2: [2]], b: [b1: [3], b2: [4]]]]
    test "is proper after splitting long span edges and inserting border segments", %{g: g, t: t} do
      ng = NestingGraph.new(g, t)

      assert %ClusteredLevelGraph{g: %{g: g}} = ng

      assert Graph.vertices(g) == [
               1,
               2,
               3,
               4,
               {:a, :+},
               {:a, :-},
               {:a1, :+},
               {:a1, :-},
               {:a2, :+},
               {:a2, :-},
               {:b, :+},
               {:b, :-},
               {:b1, :+},
               {:b1, :-},
               {:b2, :+},
               {:b2, :-},
               {:root, :+},
               {:root, :-}
             ]

      assert Graph.out_neighbours(g, 1) == [2, 4]
      assert Graph.out_neighbours(g, 2) == [3]
      assert Graph.out_neighbours(g, 3) == [4]
      assert Graph.out_neighbours(g, 4) == []
      assert Graph.out_neighbours(g, {:a, :+}) == []
      assert Graph.out_neighbours(g, {:a, :-}) == []
      assert Graph.out_neighbours(g, {:a1, :+}) == []
      assert Graph.out_neighbours(g, {:a1, :-}) == []
      assert Graph.out_neighbours(g, {:a2, :+}) == [b2: :-]
      assert Graph.out_neighbours(g, {:a2, :-}) == []
      assert Graph.out_neighbours(g, {:b, :+}) == []
      assert Graph.out_neighbours(g, {:b, :-}) == []
      assert Graph.out_neighbours(g, {:b1, :+}) == []
      assert Graph.out_neighbours(g, {:b1, :-}) == []
      assert Graph.out_neighbours(g, {:b2, :+}) == []
      assert Graph.out_neighbours(g, {:b2, :-}) == []
      assert Graph.out_neighbours(g, {:root, :+}) == []
      assert Graph.out_neighbours(g, {:root, :-}) == []

      %{
        1 => 4,
        2 => 7,
        3 => 12,
        4 => 15,
        {:a, :+} => 9,
        {:a, :-} => 2,
        {:b, :+} => 17,
        {:b, :-} => 10,
        {:a1, :+} => 5,
        {:a1, :-} => 3,
        {:a2, :+} => 8,
        {:a2, :-} => 6,
        {:b1, :+} => 13,
        {:b1, :-} => 11,
        {:b2, :+} => 16,
        {:b2, :-} => 14,
        {:root, :+} => 18,
        {:root, :-} => 1
      }
      |> Enum.each(fn {v, r} ->
        assert %{r: rank} = Graph.vertex_label(g, v)
        assert rank == r, "Vertex #{inspect(v)} has rank #{rank}, expected #{r}"
      end)

      clg =
        ClusteredLevelGraph.split_long_edges(ng)
        |> ClusteredLevelGraph.insert_border_segments()

      assert ClusteredLevelGraph.is_proper?(clg), "Expected proper graph"
    end
  end
end
