defmodule Graph.TraversalTest do
  use GraphCase

  alias Graph.Traversal

  doctest Graph.Traversal

  describe "Graph.Traversal" do
    @tag vertices: [:foo, :bar, :baz, :xyzzy]
    @tag edges: [foo: :bar, bar: :baz]
    test "components/1 returns components of a graph", %{g: g} do
      components =
        g
        |> Traversal.components()
        |> Enum.map(&MapSet.new/1)
        |> MapSet.new()

      assert Enum.count(components) == 2

      [[:foo, :bar, :baz], [:xyzzy]]
      |> Enum.each(fn vs ->
        assert MapSet.member?(components, MapSet.new(vs))
      end)
    end

    @tag vertices: [:foo, :bar, :baz, :xyzzy]
    @tag edges: [foo: :bar, bar: :baz, bar: :foo]
    test "strong_components/1 returns the strong components of a graph", %{g: g} do
      components =
        g
        |> Traversal.strong_components()
        |> Enum.map(&MapSet.new/1)
        |> MapSet.new()

      assert Enum.count(components) == 3

      [[:foo, :bar], [:baz], [:xyzzy]]
      |> Enum.each(fn vs ->
        assert MapSet.member?(components, MapSet.new(vs))
      end)
    end

    @tag vertices: [:foo, :bar, :baz, :xyzzy]
    @tag edges: [foo: :bar, bar: :baz, baz: :foo]
    test "cyclic_strong_components/1 returns the cyclic strong components of a graph", %{g: g} do
      assert [cycle] = Traversal.cyclic_strong_components(g)
      assert Enum.count(cycle) == 3
      Enum.each([:foo, :bar, :baz], fn v -> assert Enum.member?(cycle, v) end)
    end

    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy]
    test "reaching/2 returns reaching vertices", %{g: g} do
      assert Traversal.reaching([:xyzzy], g) <~> [:foo, :bar, :xyzzy]
    end

    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy]
    test "reaching/3 returns reaching vertices", %{g: g} do
      assert Traversal.reaching([:xyzzy], g, 3) <~> [:foo, :bar, :xyzzy]
    end

    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy]
    test "reaching/3 returns reaching vertices under a given limit", %{g: g} do
      assert Traversal.reaching([:xyzzy], g, 2) <~> [:bar, :xyzzy]
      assert Traversal.reaching([:xyzzy], g, 1) == [:xyzzy]
    end

    @tag edges: [foo: :bar, bar: :baz, baz: :xyzzy]
    test "reachable/3 returns reachable vertices", %{g: g} do
      assert Traversal.reachable([:foo], g, 10) <~> [:foo, :bar, :baz, :xyzzy]
    end

    @tag edges: [foo: :bar, bar: :baz, baz: :xyzzy]
    test "reachable/3 returns reachable vertices under a given limit", %{g: g} do
      assert Traversal.reachable([:foo], g, 3) <~> [:foo, :bar, :baz]
      assert Traversal.reachable([:foo], g, 1) == [:foo]
    end

    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy]
    test "reachable_neighbours/2 returns reachable neighbouring vertices", %{g: g} do
      assert Traversal.reachable_neighbours([:foo], g) <~> [:xyzzy, :baz, :bar]
    end

    @tag edges: [foo: :bar, foo: :baz, bar: :xyzzy, baz: :spqr]
    test "arborescence_root/1 returns the root of an arborescence", %{g: g} do
      assert Traversal.arborescence_root(g) == :foo
    end

    @tag edges: [a: 1, a: :b, b: 2, b: :c, c: 3, c: 4]
    test "reaching_subgraph/2 returns the subgraph of reaching vertices and edges", %{g: g} do
      assert [t1, t2] =
               [[1, 2], [3, 4]]
               |> Enum.map(&Traversal.reaching_subgraph(g, &1))

      assert Graph.vertices(t1) == [1, 2, :a, :b]
      assert Graph.vertices(t2) == [3, 4, :a, :b, :c]
      assert edges(t1) == [a: 1, a: :b, b: 2]
      assert edges(t2) == [a: :b, b: :c, c: 3, c: 4]
    end
  end
end
