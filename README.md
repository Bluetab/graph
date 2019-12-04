# Graph

A library for performing graph drawing calculations:

 * Layer assignment and nesting
 * Normalization
 * Crossing reduction
 * Positioning of nodes and edges

## Related software

 * [dagrejs/dagre](https://github.com/dagrejs/dagre), directed graph layout for JavaScript
 * [libgraph](https://github.com/bitwalker/libgraph), a graph data structure library for Elixir projects
 * Erlang OTP's [digraph](http://erlang.org/doc/man/digraph.html) and [digrap_utils](http://erlang.org/doc/man/digraph_utils.html) modules
 * [OGDF](https://ogdf.uos.de), the Open Graph Drawing Framework C++ library
 * [Graphviz](https://www.graphviz.org), an open source graph visualization software

## References

 * Sander, G. (1996). Layout of compound directed graphs.
 * Forster, M. (2002) Applying Crossing Reduction Strategies to Layered Compound Graphs. In: Goodrich M.T., Kobourov S.G. (eds) Graph Drawing. GD 2002. Lecture Notes in Computer Science, vol 2528. Springer, Berlin, Heidelberg.
 * Forster, M. (2004). A fast and simple heuristic for constrained two-level crossing reduction. In International Symposium on Graph Drawing (pp. 206-216). Springer, Berlin, Heidelberg.
 * Forster, M. (2005). Crossings in clustered level graphs.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `graph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:graph, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/graph](https://hexdocs.pm/graph).

