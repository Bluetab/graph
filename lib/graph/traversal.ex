defmodule Graph.Traversal do
  @moduledoc """
  Traversal of directed graphs. Borrows heavily from the OTP `digraph_utils`
  module.
  """

  alias Graph.Vertex

  @type vertices :: [Vertex.id()]
  @type component :: [Vertex.id()]

  @spec components(Graph.t()) :: [component]
  def components(%Graph{} = g) do
    forest(g, &inout/3)
  end

  @spec strong_components(Graph.t()) :: [component]
  def strong_components(%Graph{} = g) do
    forest(g, &inn/3, revpostorder(g))
  end

  @spec cyclic_strong_components(Graph.t()) :: [component]
  def cyclic_strong_components(%Graph{} = g) do
    g
    |> strong_components()
    |> Enum.reject(&is_singleton?(g, &1))
  end

  @spec reaching(vertices, Graph.t()) :: vertices
  def reaching([], %Graph{}), do: []

  def reaching(vs, %Graph{} = g) when is_list(vs) do
    g
    |> forest(&inn/3, vs, :first)
    |> Enum.concat()
  end

  @spec reaching(vertices, Graph.t(), :pos_integer) :: vertices
  def reaching([], %Graph{}, _limit), do: []

  def reaching(vs, %Graph{} = g, limit) do
    g
    |> do_traverse(MapSet.new(vs), &Graph.in_neighbours/2, MapSet.new(), limit)
    |> MapSet.to_list()
  end

  @spec reachable(vertices, Graph.t()) :: vertices
  def reachable([], %Graph{}), do: []

  def reachable(vs, %Graph{} = g) when is_list(vs) do
    g
    |> forest(&out/3, vs, :first)
    |> Enum.concat()
  end

  @spec reachable(vertices, Graph.t(), :pos_integer) :: vertices
  def reachable([], %Graph{}, _limit), do: []

  def reachable(vs, %Graph{} = g, limit) do
    g
    |> do_traverse(MapSet.new(vs), &Graph.out_neighbours/2, MapSet.new(), limit)
    |> MapSet.to_list()
  end

  @spec reaching_subgraph(Graph.t(), [Vertex.id()]) :: Graph.t()
  def reaching_subgraph(%Graph{} = g, vs) do
    Graph.subgraph(g, reaching(vs, g))
  end

  @spec reachable_subgraph(Graph.t(), [Vertex.id()]) :: Graph.t()
  def reachable_subgraph(%Graph{} = g, vs) do
    Graph.subgraph(g, reachable(vs, g))
  end

  @spec reachable_neighbours(vertices, Graph.t()) :: vertices
  def reachable_neighbours(vs, %Graph{} = g) when is_list(vs) do
    g
    |> forest(&out/3, vs, :not_first)
    |> Enum.concat()
  end

  @spec arborescence_root(Graph.t()) :: Vertex.id() | nil
  def arborescence_root(%Graph{} = g) do
    if Graph.no_edges(g) == Graph.no_vertices(g) - 1 do
      f = fn v, z ->
        case Graph.in_degree(g, v) do
          1 -> z
          0 when z == [] -> [v]
        end
      end

      roots =
        g
        |> Graph.vertices()
        |> List.foldl([], f)

      case roots do
        [root] -> root
        _ -> nil
      end
    end
  end

  @spec topsort(Graph.t()) :: false | vertices
  def topsort(%Graph{vertices: vs} = g) do
    l = revpostorder(g)

    case Enum.count(forest(g, &inn/3, l)) == Enum.count(vs) do
      true -> l
      false -> false
    end
  end

  @spec inn(Graph.t(), Graph.id(), vertices) :: vertices
  defp inn(%Graph{} = g, v, vs) do
    Graph.in_neighbours(g, v) ++ vs
  end

  @spec out(Graph.t(), Graph.id(), vertices) :: vertices
  defp out(%Graph{} = g, v, vs) do
    Graph.out_neighbours(g, v) ++ vs
  end

  @spec inout(Graph.t(), Graph.id(), vertices) :: vertices
  defp inout(g, v, vs) do
    inn(g, v, out(g, v, vs))
  end

  defp forest(%Graph{} = g, sf), do: forest(g, sf, Graph.vertices(g))
  defp forest(%Graph{} = g, sf, vs), do: forest(g, sf, vs, :first)

  defp forest(%Graph{} = g, sf, vs, handle_first) do
    t = :ets.new(:forest, [:set])
    f = fn v, ll -> pretraverse(handle_first, v, sf, g, t, ll) end
    ll = :lists.foldl(f, [], vs)
    :ets.delete(t)
    ll
  end

  defp do_traverse(_g, vs, _f, visited, 0), do: MapSet.union(visited, vs)

  defp do_traverse(%Graph{} = g, vs, f, visited, n) do
    case MapSet.size(vs) do
      0 ->
        visited

      _ ->
        neighbours =
          vs
          |> Enum.flat_map(&f.(g, &1))
          |> MapSet.new()
          |> MapSet.difference(visited)

        visited =
          visited
          |> MapSet.union(vs)
          |> MapSet.union(neighbours)

        do_traverse(g, neighbours, f, visited, n - 1)
    end
  end

  defp pretraverse(:first, v, sf, g, t, ll) do
    ptraverse([v], sf, g, t, [], ll)
  end

  defp pretraverse(:not_first, v, sf, g, t, ll) do
    case :ets.member(t, v) do
      false -> ptraverse(sf.(g, v, []), sf, g, t, [], ll)
      true -> ll
    end
  end

  defp ptraverse([v | vs], sf, g, t, rs, ll) do
    case :ets.member(t, v) do
      false ->
        :ets.insert(t, {v})
        ptraverse(sf.(g, v, vs), sf, g, t, [v | rs], ll)

      true ->
        ptraverse(vs, sf, g, t, rs, ll)
    end
  end

  defp ptraverse([], _sf, _g, _t, [], ll), do: ll
  defp ptraverse([], _sf, _g, _t, rs, ll), do: [rs | ll]

  defp revpostorder(%Graph{} = g) do
    t = :ets.new(:forest, [:set])
    l = posttraverse(Graph.vertices(g), g, t, [])
    :ets.delete(t)
    l
  end

  defp posttraverse([v | vs], g, t, l) do
    l1 =
      case :ets.member(t, v) do
        false ->
          :ets.insert(t, {v})
          [v | posttraverse(out(g, v, []), g, t, l)]

        true ->
          l
      end

    posttraverse(vs, g, t, l1)
  end

  defp posttraverse([], _g, _t, l), do: l

  @spec is_singleton?(Graph.t(), component) :: boolean
  defp is_singleton?(g, c)

  defp is_singleton?(%Graph{} = g, [v]) do
    not is_reflexive_vertex(g, v)
  end

  defp is_singleton?(%Graph{} = _g, _), do: false

  def loop_vertices(%Graph{} = g) do
    g
    |> Graph.vertices()
    |> Enum.filter(&is_reflexive_vertex(g, &1))
  end

  def post_order(%Graph{} = g) do
    g
    |> topsort()
    |> Enum.reverse()
  end

  defp is_reflexive_vertex(%Graph{} = g, v) do
    g
    |> Graph.out_neighbours(v)
    |> Enum.member?(v)
  end
end
