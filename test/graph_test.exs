defmodule GraphTest do
  use ExUnit.Case

  alias Graph
  alias Graph.Edge

  doctest Graph

  describe "A graph" do
    test "get_path/3 returns a path" do
      g =
        [:foo, :bar, :baz, :xyzzy, :spqr]
        |> Graph.new()
        |> Graph.add_edges(foo: :bar, bar: :baz, bar: :xyzzy, baz: :spqr, xyzzy: :spqr)

      assert Graph.get_path(g, :foo, :spqr) == [:foo, :bar, :baz, :spqr]
    end

    test "del_path/3 deletes all paths between two vertices" do
      g =
        [:foo, :bar, :baz, :xyzzy, :spqr]
        |> Graph.new()
        |> Graph.add_edges(foo: :bar, bar: :baz, bar: :xyzzy, baz: :spqr, xyzzy: :spqr)
        |> Graph.del_path(:foo, :spqr)

      refute Graph.get_path(g, :foo, :spqr)
    end

    test "is_tree/1 returns true iff a graph is a tree" do
      g =
        [:foo, :bar, :baz, :xyzzy, :spqr]
        |> Graph.new()
        |> Graph.add_edges(foo: :bar, baz: :foo, bar: :xyzzy, baz: :spqr)

      assert Graph.is_tree(g)
      refute Graph.is_tree(Graph.add_edge(g, :spqr, :xyzzy))
    end

    test "is_arborescence/1 returns true if a graph is an arborescence" do
      g =
        [:foo, :bar, :baz, :xyzzy, :spqr]
        |> Graph.new()
        |> Graph.add_edges(foo: :bar, foo: :baz, bar: :xyzzy, baz: :spqr, spqr: :xyzzy)

      assert Graph.is_arborescence(g)
    end

    test "get_cycle/2 returns long and short cycles" do
      g =
        [:foo, :bar, :baz, :xyzzy, :spqr]
        |> Graph.new()
        |> Graph.add_edges(foo: :foo, foo: :bar, bar: :baz, baz: :foo, xyzzy: :foo, spqr: :baz)

      assert Graph.get_cycle(g, :missing) == {:error, {:bad_vertex, :missing}}
      refute Graph.get_cycle(g, :spqr)
      assert Graph.get_cycle(g, :foo) == [:foo, :bar, :baz, :foo]

      g = Graph.add_edges(g, xyzzy: :xyzzy)
      assert Graph.get_cycle(g, :xyzzy) == [:xyzzy]
    end

    test ":digraph.get_short_cycle/2" do
      g = :digraph.new()

      [:foo, :bar, :baz, :xyzzy, :spqr]
      |> Enum.each(&:digraph.add_vertex(g, &1))

      [foo: :foo, foo: :bar, bar: :baz, baz: :foo, xyzzy: :foo, spqr: :baz, xyzzy: :xyzzy]
      |> Enum.each(fn {v1, v2} -> :digraph.add_edge(g, v1, v2) end)

      refute :digraph.get_short_cycle(g, :spqr)
      assert :digraph.get_short_cycle(g, :foo) == [:foo, :foo]
      assert :digraph.get_short_cycle(g, :xyzzy) == [:xyzzy, :xyzzy]
    end

    test "get_short_cycle/2 returns short cycles" do
      g =
        [:foo, :bar, :baz, :xyzzy, :spqr]
        |> Graph.new()
        |> Graph.add_edges(foo: :foo, foo: :bar, bar: :baz, baz: :foo, xyzzy: :foo, spqr: :baz)
        |> Graph.add_edges(xyzzy: :xyzzy)

      refute Graph.get_short_cycle(g, :spqr)
      assert Graph.get_short_cycle(g, :foo) == [:foo, :foo]
      assert Graph.get_short_cycle(g, :xyzzy) == [:xyzzy, :xyzzy]
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
