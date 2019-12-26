defmodule Graph.CoordinateAssignmentTest do
  use GraphCase

  alias Graph.CoordinateAssignment
  alias Graph.LevelGraph

  describe "Graph.CoordinateAssignment" do
    @tag vertices:
           [
             [11, 12],
             [21, 22, 23, 24, 25, 26, 27, 28],
             [31, 32, 33, 34, 35, 36],
             [41, 42, 43, 44, 45, 46, 47],
             [51, 52, 53]
           ]
           |> Enum.with_index(1)
           |> Enum.flat_map(fn {vs, r} ->
             vs
             |> Enum.with_index(1)
             |> Enum.map(fn {v, b} -> {v, %{r: r, b: b}} end)
           end)
           |> Map.new()
    @tag edges:
           [
             [{11, 21}, {11, 26}, {11, 28}, {12, 23}, {12, 25}],
             # [{22, 32}, {23, 32}, {27, 32}, {28, 32}]
             [{24, 32}, {25, 33}, {26, 34}, {27, 36}, {28, 35}],
             [{31, 41}, {31, 42}, {31, 46}, {33, 44}, {34, 45}, {35, 46}, {36, 43}, {36, 47}],
             # [{44, 53}, {47, 53}]
             [{41, 51}, {41, 52}, {42, 52}, {43, 51}, {45, 53}, {46, 53}]
           ]
           |> Enum.flat_map(& &1)
    test "type1 conflicts", %{g: g} do
      lg =
        [23, 25, 26, 33, 34, 35, 43, 44, 45, 47]
        |> Enum.reduce(
          LevelGraph.new(g, fn g, v -> Graph.vertex(g, v, :r) end),
          &LevelGraph.put_label(&2, &1, %{dummy: true})
        )

      conflicts = CoordinateAssignment.type1_conflicts(lg)

      assert conflicts == [{36, 43}, {31, 46}]
    end
  end
end
