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
  end
end
