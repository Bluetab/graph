defmodule Graph.Drawing.GridTest do
  use GraphCase
  use TreeCase

  alias Graph.Drawing.Dimensions
  alias Graph.Drawing.Grid
  alias Graph.Layout

  describe "Graph.Drawing.Grid" do
    @tag edges: [a1: :a2, a2: :b1, b1: :b2, b2: :a2]
    @tag tree: [root: [a: [:a1, :a2], b: [:b1, :b2]]]
    test "Grid.new/4 calculates x and y scales correctly", %{g: g, t: t} do
      assert %Layout{graph: %{g: lg, t: t}} = Layout.layout(g, t, [:a1], type: :impact)

      assert %Grid{x_scale: x_scale, y_scale: y_scale} =
               Grid.new(lg, Dimensions.width_fn(), Dimensions.height_fn(),
                 x_spacing: 20,
                 y_spacing: 10,
                 x_padding: 0
               )

      assert x_scale == %{
               1 => %{w: 0, left: 0, mid: 0, right: 0},
               2 => %{w: 0, left: 20, mid: 20, right: 20},
               3 => %{w: 200, left: 40, mid: 140, right: 240},
               4 => %{w: 200, left: 260, mid: 360, right: 460},
               5 => %{w: 0, left: 480, mid: 480, right: 480},
               6 => %{w: 0, left: 500, mid: 500, right: 500},
               7 => %{w: 200, left: 520, mid: 620, right: 720},
               8 => %{w: 200, left: 740, mid: 840, right: 940},
               9 => %{w: 0, left: 960, mid: 960, right: 960},
               10 => %{w: 0, left: 980, mid: 980, right: 980}
             }

      assert y_scale == %{
               0.0 => %{h: 26, bottom: 26, mid: 13, top: 0},
               2.0 => %{h: 26, bottom: 62, mid: 49, top: 36},
               4.0 => %{h: 22, bottom: 94, mid: 83, top: 72},
               6.0 => %{h: 22, bottom: 126, mid: 115, top: 104},
               8.0 => %{h: 10, bottom: 146, mid: 141, top: 136},
               10.0 => %{h: 10, bottom: 166, mid: 161, top: 156}
             }
    end
  end
end
