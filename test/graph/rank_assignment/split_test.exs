defmodule Bluetab.Graph.RankAssignment.SplitTest do
  use Bluetab.GraphCase
  use TreeCase

  alias Bluetab.Graph.RankAssignment.Split

  doctest Split

  @vertex_ranks [root: [1..4], g1: [1..2, 4..4], g2: [3..3], a: 1, b: 2, c: 3, d: 4, e: 3]

  setup %{t: t} do
    t = Enum.reduce(@vertex_ranks, t, fn {v, r}, t -> Bluetab.Graph.put_label(t, v, %{r: r}) end)
    %{t: t}
  end

  describe "Bluetab.Graph.RankAssignment.Split" do
    @tag tree: [root: [g1: [:a, :b, :d], g2: [:c, :e]]]
    test "splits multi-span clusters by span", %{t: t} do
      assert Bluetab.Graph.vertex(t, :root, :r) ||| [1..4]
      assert %Bluetab.Graph{} = t = Split.split_clusters(t)
      assert Bluetab.Graph.arborescence?(t)

      assert Bluetab.Graph.vertices(t) |||
               [:a, :b, :c, :d, :e, :g2, :root, {:g1, 1..2}, {:g1, 4..4}]

      assert Bluetab.Graph.vertex(t, {:g1, 1..2}, :r) == 1..2
      assert Bluetab.Graph.vertex(t, {:g1, 4..4}, :r) == 4..4
      assert out_neighbours(t, {:g1, 1..2}) ||| [:a, :b]
      assert out_neighbours(t, {:g1, 4..4}) ||| [:d]
    end
  end
end
