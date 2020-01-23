defmodule Graph.RankAssignment.SplitTest do
  use GraphCase
  use TreeCase

  alias Graph.RankAssignment.Split

  doctest Split

  @vertex_ranks [root: [1..4], g1: [1..2, 4..4], g2: [3..3], a: 1, b: 2, c: 3, d: 4, e: 3]

  setup %{t: t} do
    t = Enum.reduce(@vertex_ranks, t, fn {v, r}, t -> Graph.put_label(t, v, %{r: r}) end)
    %{t: t}
  end

  describe "Graph.RankAssignment.Split" do
    @tag tree: [root: [g1: [:a, :b, :d], g2: [:c, :e]]]
    test "splits multi-span clusters by span", %{t: t} do
      assert Graph.vertex(t, :root, :r) == [1..4]
      assert %Graph{} = t = Split.split_clusters(t)
      assert Graph.is_arborescence(t)
      assert Graph.vertices(t) == [:a, :b, :c, :d, :e, :g2, :root, {:g1, 1..2}, {:g1, 4..4}]
      assert Graph.vertex(t, {:g1, 1..2}, :r) == 1..2
      assert Graph.vertex(t, {:g1, 4..4}, :r) == 4..4
      assert out_neighbours(t, {:g1, 1..2}) == [:a, :b]
      assert out_neighbours(t, {:g1, 4..4}) == [:d]
    end
  end
end
