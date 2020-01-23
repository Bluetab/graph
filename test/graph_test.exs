defmodule GraphTest do
  use GraphCase

  alias Graph.Edge

  doctest Graph

  describe "A graph" do
    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy, baz: :spqr, xyzzy: :spqr]
    test "get_path/3 returns a path", %{g: g} do
      assert [:foo, :bar, v, :spqr] = Graph.get_path(g, :foo, :spqr)
      assert Enum.member?([:baz, :xyzzy], v)
    end

    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy, baz: :spqr, xyzzy: :spqr]
    test "get_path/3 returns nil if no path exists", %{g: g} do
      refute Graph.get_path(g, :spqr, :baz)
    end

    @tag edges: [foo: :bar, bar: :baz, bar: :xyzzy, baz: :spqr, xyzzy: :spqr]
    test "del_path/3 deletes all paths between two vertices", %{g: g} do
      g = Graph.del_path(g, :foo, :spqr)
      refute Graph.get_path(g, :foo, :spqr)
    end

    @tag edges: [foo: :bar, baz: :foo, bar: :xyzzy, baz: :spqr]
    test "is_tree/1 returns true iff a graph is a tree", %{g: g} do
      assert Graph.is_tree(g)
      refute Graph.is_tree(Graph.add_edge(g, :spqr, :xyzzy))
    end

    @tag edges: [foo: :bar, foo: :baz, bar: :xyzzy, baz: :spqr]
    test "is_arborescence/1 returns true if a graph is an arborescence", %{g: g} do
      assert Graph.is_arborescence(g)
    end

    @tag edges: [foo: :foo, foo: :bar, bar: :baz, baz: :foo, xyzzy: :foo, spqr: :baz]
    test "get_cycle/2 returns long and short cycles", %{g: g} do
      assert Graph.get_cycle(g, :missing) == {:error, {:bad_vertex, :missing}}
      refute Graph.get_cycle(g, :spqr)
      assert Graph.get_cycle(g, :foo) == [:foo, :bar, :baz, :foo]

      g = Graph.add_edges(g, xyzzy: :xyzzy)
      assert Graph.get_cycle(g, :xyzzy) == [:xyzzy]
    end

    @tag edges: [
           foo: :foo,
           foo: :bar,
           bar: :baz,
           baz: :foo,
           xyzzy: :foo,
           spqr: :baz,
           xyzzy: :xyzzy
         ]
    test "get_short_cycle/2 returns short cycles", %{g: g} do
      refute Graph.get_short_cycle(g, :spqr)
      assert Graph.get_short_cycle(g, :foo) == [:foo, :foo]
      assert Graph.get_short_cycle(g, :xyzzy) == [:xyzzy, :xyzzy]
    end

    @tag edges: [foo: :bar, bar: :baz, xyzzy: :baz]
    test "source_vertices/1 returns vertices with in_degree 0", %{g: g} do
      assert Graph.source_vertices(g) == [:foo, :xyzzy]
    end

    @tag edges: [foo: :bar, bar: :baz, xyzzy: :baz, bar: :spqr]
    test "sink_vertices/1 returns vertices with out_degree 0", %{g: g} do
      assert Graph.sink_vertices(g) == [:baz, :spqr]
    end

    @tag edges: [foo: :bar, bar: :baz, xyzzy: :baz, bar: :spqr]
    test "inner_vertices/1 returns vertices with degree > 0", %{g: g} do
      assert Graph.inner_vertices(g) == [:bar]
    end

    @tag edges: [foo: :bar, bar: :baz, xyzzy: :baz, bar: :spqr]
    test "in_vertices/1 returns vertices with in_degree > 0", %{g: g} do
      assert Graph.in_vertices(g) == [:bar, :baz, :spqr]
    end
  end

  describe "An acyclic graph" do
    test "add_edge/3 fails if it would create a cycle in an acyclic graph" do
      g = Graph.new([:foo, :bar], acyclic: true)
      assert g = Graph.add_edge(g, :foo, :bar)
      assert Graph.add_edge(g, :bar, :foo) == {:error, {:bad_edge, [:foo, :bar]}}
    end
  end
end
