defmodule Graph.LevelGraphTest do
  use GraphCase

  alias Graph.LevelGraph

  describe "Graph.LevelGraph" do
    @tag edges: [{11, 21}, {12, 22}, {13, 21}, {14, 23}]
    test "new/2 returns a new level graph", %{g: g} do
      assert lg = LevelGraph.new(g)
      Enum.each([11, 12, 13, 14], fn v -> assert LevelGraph.level(lg, v) == 1 end)
      Enum.each([21, 22, 23], fn v -> assert LevelGraph.level(lg, v) == 2 end)
    end

    @tag edges: [{11, 21}, {12, 22}, {13, 21}, {14, 23}]
    test "vertices_by_level/2 returns the vertices of the level", %{g: g} do
      assert lg = LevelGraph.new(g)
      assert LevelGraph.vertices_by_level(lg, 1) == [11, 12, 13, 14]
      assert LevelGraph.vertices_by_level(lg, 2) == [21, 22, 23]
    end

    @tag vertices: Map.new(1..10, fn l -> {l, %{r: l}} end)
    @tag edges: [{1, 2}, {1, 3}, {2, 4}]
    test "subgraph/2 returns a subgraph of the level graph", %{g: g} do
      assert lg = LevelGraph.new(g, :r)
      assert lg = LevelGraph.subgraph(lg, [1, 2, 3])
      assert %{g: g} = lg
      assert Graph.vertices(g) == [1, 2, 3]

      assert [e1, e2] =
               g |> Graph.get_edges() |> Enum.sort_by(fn %{v1: v1, v2: v2} -> {v1, v2} end)

      assert %{v1: 1, v2: 2} = e1
      assert %{v1: 1, v2: 3} = e2

      Enum.each(1..3, fn v ->
        assert LevelGraph.level(lg, v) == v
      end)
    end

    @tag vertices: Map.new(0..11, fn l -> {l, %{b: l + 1, r: 1 + Integer.floor_div(l, 4)}} end)
    test "predecessor_map/1 returns a map of vertices with their predecessor", %{g: g} do
      pm =
        g
        |> LevelGraph.new(&rank/2)
        |> LevelGraph.predecessor_map()

      assert pm == %{1 => 0, 2 => 1, 3 => 2, 5 => 4, 6 => 5, 7 => 6, 9 => 8, 10 => 9, 11 => 10}
    end
  end

  defp rank(g, v) do
    g
    |> Graph.vertex_label(v)
    |> Map.get(:r)
  end
end
