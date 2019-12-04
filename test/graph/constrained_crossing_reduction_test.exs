defmodule Graph.ConstrainedCrossingReductionTest do
  use GraphCase

  alias Graph.ConstrainedCrossingReduction
  alias Graph.ConstraintGraph

  @order [{:l, :c2}, 1, 2, {:r, :c2}, 3, {:l, :c1}, {:l, :c3}, 4, 5, {:r, :c3}, {:r, :c1}]

  setup tags do
    case tags[:constraints] do
      constraints when is_list(constraints) ->
        [gc: ConstraintGraph.new(constraints)]

      _ ->
        :ok
    end
  end

  describe "Graph.ConstrainedCrossingReduction" do
    @tag vertices: Enum.with_index(@order) |> Map.new(fn {v, b} -> {v, %{b: b + 1}} end)
    @tag edges: [
           # {1, :c2},
           {{:l, :c2}, :c2},
           # {2, :c2}, {2, :c2},
           {1, :c2},
           {2, :c2},
           {{:r, :c2}, :c2},
           {2, :f},
           {3, :c2},
           {3, :e},
           {{:l, :c1}, :c3},
           {{:l, :c3}, :c3},
           # {4, :c3}, {4, :c3},
           {4, :f},
           {4, :c3},
           {5, :c3},
           {{:r, :c3}, :c3},
           {{:r, :c1}, :c3}
         ]
    @tag constraints: [c2: :c3]
    test "permute/4 returns a permutation of v2", %{g: g, gc: gc} do
      b = barycenter_fn(g)
      v2 = [:c3, :e, :f, :c2]
      assert ConstrainedCrossingReduction.permute(g, gc, v2, b) == [:c2, :e, :f, :c3]
    end
  end
end
