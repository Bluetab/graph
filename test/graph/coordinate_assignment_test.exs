defmodule Graph.CoordinateAssignmentTest do
  use GraphCase

  alias Graph.CoordinateAssignment
  alias Graph.LevelGraph

  @levels [
    [11, 12],
    [21, 22, 23, 24, 25, 26, 27, 28],
    [31, 32, 33, 34, 35, 36],
    [41, 42, 43, 44, 45, 46, 47],
    [51, 52, 53]
  ]
  @edges [
           [{11, 21}, {11, 26}, {11, 28}, {12, 23}, {12, 25}],
           # [{22, 32}, {23, 32}, {27, 32}, {28, 32}]
           [{24, 32}, {25, 33}, {26, 34}, {27, 36}, {28, 35}],
           [{31, 41}, {31, 42}, {31, 46}, {33, 44}, {34, 45}, {35, 46}, {36, 43}, {36, 47}],
           # [{44, 53}, {47, 53}]
           [{41, 51}, {41, 52}, {42, 52}, {43, 51}, {45, 53}, {46, 53}]
         ]
         |> Enum.flat_map(& &1)
  @vertices @levels
            |> Enum.with_index(1)
            |> Enum.flat_map(fn {vs, r} ->
              vs
              |> Enum.with_index(1)
              |> Enum.map(fn {v, b} -> {v, %{r: r, b: b}} end)
            end)
            |> Map.new()
  @dummies [23, 25, 26, 33, 34, 35, 43, 44, 45, 47]

  setup context do
    case context do
      %{dummies: dummies, g: g} ->
        lg =
          Enum.reduce(
            dummies,
            LevelGraph.new(g, fn g, v -> Graph.vertex(g, v, :r) end),
            &LevelGraph.put_label(&2, &1, %{dummy: true})
          )

        Map.put(context, :lg, lg)

      c ->
        c
    end
  end

  describe "Graph.CoordinateAssignment" do
    @tag vertices: @vertices
    @tag edges: @edges
    @tag dummies: @dummies
    test("type1 conflicts and vertical assignment", %{lg: lg}) do
      conflicts = CoordinateAssignment.type1_conflicts(lg)

      assert conflicts ||| [{36, 43}, {31, 46}]

      root = CoordinateAssignment.vertical_alignment(lg, conflicts)

      assert root == %{
               11 => 11,
               12 => 12,
               21 => 11,
               22 => 22,
               23 => 12,
               24 => 24,
               25 => 25,
               26 => 26,
               27 => 27,
               28 => 28,
               31 => 31,
               32 => 24,
               33 => 25,
               34 => 26,
               35 => 28,
               36 => 36,
               41 => 31,
               42 => 42,
               43 => 43,
               44 => 25,
               45 => 26,
               46 => 28,
               47 => 36,
               51 => 31,
               52 => 42,
               53 => 26
             }
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag dummies: @dummies
    test("coordinate assignment: type 1 conflicts, alignment and compaction", %{lg: lg}) do
      assert %LevelGraph{g: g} = CoordinateAssignment.assign_x(lg)

      assert g
             |> Graph.vertices()
             |> Enum.group_by(&Graph.vertex(g, &1, :x)) ==
               %{
                 0 => [11, 21],
                 2 => [22, 31, 41, 51],
                 4 => [12, 23, 42, 52],
                 6 => [24, 32, 43],
                 8 => [25, 33, 44],
                 10 => [26, 34, 45, 53],
                 12 => [27],
                 14 => [28, 35, 46],
                 16 => [36, 47]
               }
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag dummies: @dummies
    test("coordinate assignment: average median position", %{lg: lg}) do
      assert %LevelGraph{g: g} = CoordinateAssignment.assign_avg_x(lg)

      assert g
             |> Graph.vertices()
             |> Enum.group_by(&Graph.vertex(g, &1, :x)) ==
               %{
                 0.0 => [21],
                 2.0 => [22, 41, 51],
                 3.0 => [31],
                 4.0 => [23, 42, 52],
                 5.0 => [11],
                 6.0 => [24, 32, 43],
                 8.0 => [12, 25, 33, 44],
                 10.0 => [26, 34, 45, 53],
                 13.0 => [27, 35, 46],
                 15.0 => [28, 36, 47]
               }
    end
  end
end
