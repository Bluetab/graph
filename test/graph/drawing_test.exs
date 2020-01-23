defmodule Graph.DrawingTest do
  use GraphCase
  use TreeCase

  alias Graph.Drawing
  alias Graph.Layout

  setup %{t: t, g: g} = _context do
    t =
      t
      |> Graph.vertices()
      |> Enum.reduce(t, &Graph.put_label(&2, &1, id: &1))

    g =
      g
      |> Graph.vertices()
      |> Enum.reduce(g, &Graph.put_label(&2, &1, id: &1))

    [layout: Layout.layout(g, t, [:a1], type: :impact)]
  end

  describe "Graph.Drawing" do
    @tag edges: [a1: :a2, a2: :b1, b1: :b2, b2: :a2]
    @tag tree: [r: [a: [:a1, :a2], b: [:b1, :b2]]]
    test "Drawing.new/4 calculates group coordinates and dimensions", %{layout: layout} do
      assert %Drawing{} = d = Drawing.new(layout, &label_fn/1)
      assert %{groups: groups} = d

      assert groups ==
               [
                 %{id: :r, h: 134, w: 1060, x: 0, y: 0, z: 0},
                 %{id: :a, h: 78, w: 460, x: 20, y: 36, z: 1},
                 %{id: :b, h: 78, w: 460, x: 580, y: 36, z: 1}
               ]
    end

    @tag edges: [a1: :a2, a2: :b1, b1: :b2, b2: :a2]
    @tag tree: [root: [a: [:a1, :a2], b: [:b1, :b2]]]
    test "Drawing.new/4 calculates paths", %{layout: layout} do
      assert %Drawing{} = d = Drawing.new(layout, &label_fn/1)
      assert %{paths: paths} = d

      assert paths ==
               [
                 %{v1: :a1, v2: :a2, path: "M 240 83 L 260 83"},
                 %{v1: :a2, v2: :b1, path: "M 460 83 L 480 83 L 580 83 L 600 83"},
                 %{v1: :a2, v2: :b2, path: "M 820 83 L 700 109 L 580 109 L 480 109 L 460 83"},
                 %{v1: :b1, v2: :b2, path: "M 800 83 L 820 83"}
               ]
    end

    @tag edges: [a1: :a2, a2: :b1, b1: :b2, b2: :a2]
    @tag tree: [root: [a: [:a1, :a2], b: [:b1, :b2]]]
    test "Drawing.new/4 calculates resource positions and dimensions", %{layout: layout} do
      assert %Drawing{} = d = Drawing.new(layout, &label_fn/1)
      assert %{resources: resources} = d

      assert resources ==
               [
                 %{id: :a1, h: 22, w: 200, x: 40, y: 72},
                 %{id: :a2, h: 22, w: 200, x: 260, y: 72},
                 %{id: :b1, h: 22, w: 200, x: 600, y: 72},
                 %{id: :b2, h: 22, w: 200, x: 820, y: 72}
               ]
    end
  end

  def label_fn(%{id: id}), do: %{id: id}
end
