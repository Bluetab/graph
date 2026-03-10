defmodule Bluetab.Graph.Traversal do
  @moduledoc """
  Traversal of directed graphs. Borrows heavily from the OTP `digraph_utils`
  module.
  """

  alias Bluetab.Graph.Vertex

  @type vertices :: [Vertex.id()]
  @type component :: [Vertex.id()]

  @spec components(Bluetab.Graph.t()) :: [component]
  def components(%Bluetab.Graph{} = g) do
    forest(g, &inout/3)
  end

  @spec strong_components(Bluetab.Graph.t()) :: [component]
  def strong_components(%Bluetab.Graph{} = g) do
    forest(g, &inn/3, revpostorder(g))
  end

  @spec cyclic_strong_components(Bluetab.Graph.t()) :: [component]
  def cyclic_strong_components(%Bluetab.Graph{} = g) do
    g
    |> strong_components()
    |> Enum.reject(&singleton?(g, &1))
  end

  @spec reaching(vertices, Bluetab.Graph.t()) :: vertices
  def reaching([], %Bluetab.Graph{}), do: []

  def reaching(vs, %Bluetab.Graph{} = g) when is_list(vs) do
    g
    |> forest(&inn/3, vs, :first)
    |> Enum.concat()
  end

  @spec reaching(vertices, Bluetab.Graph.t(), :pos_integer) :: vertices
  def reaching([], %Bluetab.Graph{}, _limit), do: []

  def reaching(vs, %Bluetab.Graph{} = g, limit) do
    vs =
      vs
      |> Enum.filter(&Bluetab.Graph.has_vertex?(g, &1))
      |> MapSet.new()

    g
    |> do_traverse(vs, &Bluetab.Graph.in_neighbours/2, vs, limit)
    |> MapSet.to_list()
  end

  @spec reachable(vertices, Bluetab.Graph.t()) :: vertices
  def reachable([], %Bluetab.Graph{}), do: []

  def reachable(vs, %Bluetab.Graph{} = g) when is_list(vs) do
    g
    |> forest(&out/3, vs, :first)
    |> Enum.concat()
  end

  @spec reachable(vertices, Bluetab.Graph.t(), :pos_integer) :: vertices
  def reachable([], %Bluetab.Graph{}, _limit), do: []

  def reachable(vs, %Bluetab.Graph{} = g, limit) do
    vs =
      vs
      |> Enum.filter(&Bluetab.Graph.has_vertex?(g, &1))
      |> MapSet.new()

    g
    |> do_traverse(vs, &Bluetab.Graph.out_neighbours/2, vs, limit)
    |> MapSet.to_list()
  end

  @spec reaching_subgraph(Bluetab.Graph.t(), [Vertex.id()]) :: Bluetab.Graph.t()
  def reaching_subgraph(%Bluetab.Graph{} = g, vs) do
    Bluetab.Graph.subgraph(g, reaching(vs, g))
  end

  @spec reachable_subgraph(Bluetab.Graph.t(), [Vertex.id()]) :: Bluetab.Graph.t()
  def reachable_subgraph(%Bluetab.Graph{} = g, vs) do
    Bluetab.Graph.subgraph(g, reachable(vs, g))
  end

  @spec reachable_neighbours(vertices, Bluetab.Graph.t()) :: vertices
  def reachable_neighbours(vs, %Bluetab.Graph{} = g) when is_list(vs) do
    g
    |> forest(&out/3, vs, :not_first)
    |> Enum.concat()
  end

  @spec arborescence_root(Bluetab.Graph.t()) :: Vertex.id() | nil
  def arborescence_root(%Bluetab.Graph{} = g) do
    if Bluetab.Graph.no_edges(g) == Bluetab.Graph.no_vertices(g) - 1 do
      f = fn v, z ->
        case Bluetab.Graph.in_degree(g, v) do
          1 -> z
          0 when z == [] -> [v]
        end
      end

      roots =
        g
        |> Bluetab.Graph.vertices()
        |> List.foldl([], f)

      case roots do
        [root] -> root
        _ -> nil
      end
    end
  end

  @spec topsort(Bluetab.Graph.t()) :: false | vertices
  def topsort(%Bluetab.Graph{vertices: vs} = g) do
    l = revpostorder(g)

    case Enum.count(forest(g, &inn/3, l)) == Enum.count(vs) do
      true -> l
      false -> false
    end
  end

  @spec inn(Bluetab.Graph.t(), Bluetab.Graph.id(), vertices) :: vertices
  defp inn(%Bluetab.Graph{} = g, v, vs) do
    Bluetab.Graph.in_neighbours(g, v) ++ vs
  end

  @spec out(Bluetab.Graph.t(), Bluetab.Graph.id(), vertices) :: vertices
  defp out(%Bluetab.Graph{} = g, v, vs) do
    Bluetab.Graph.out_neighbours(g, v) ++ vs
  end

  @spec inout(Bluetab.Graph.t(), Bluetab.Graph.id(), vertices) :: vertices
  defp inout(g, v, vs) do
    inn(g, v, out(g, v, vs))
  end

  defp forest(%Bluetab.Graph{} = g, sf), do: forest(g, sf, Bluetab.Graph.vertices(g))
  defp forest(%Bluetab.Graph{} = g, sf, vs), do: forest(g, sf, vs, :first)

  defp forest(%Bluetab.Graph{} = g, sf, vs, handle_first) do
    t = :ets.new(:forest, [:set])
    f = fn v, ll -> pretraverse(handle_first, v, sf, g, t, ll) end
    ll = :lists.foldl(f, [], vs)
    :ets.delete(t)
    ll
  end

  defp do_traverse(_g, _vs, _f, visited, n) when n <= 1, do: visited

  defp do_traverse(%Bluetab.Graph{} = g, vs, f, visited, n) do
    case MapSet.size(vs) do
      0 ->
        visited

      _ ->
        neighbours =
          vs
          |> Enum.flat_map(&f.(g, &1))
          |> MapSet.new()
          |> MapSet.difference(visited)

        do_traverse(g, neighbours, f, MapSet.union(visited, neighbours), n - 1)
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

  defp revpostorder(%Bluetab.Graph{} = g) do
    t = :ets.new(:forest, [:set])
    l = posttraverse(Bluetab.Graph.vertices(g), g, t, [])
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

  @spec singleton?(Bluetab.Graph.t(), component) :: boolean
  defp singleton?(g, c)

  defp singleton?(%Bluetab.Graph{} = g, [v]) do
    not reflexive_vertex?(g, v)
  end

  defp singleton?(%Bluetab.Graph{} = _g, _), do: false

  def loop_vertices(%Bluetab.Graph{} = g) do
    g
    |> Bluetab.Graph.vertices()
    |> Enum.filter(&reflexive_vertex?(g, &1))
  end

  def post_order(%Bluetab.Graph{} = g) do
    g
    |> topsort()
    |> Enum.reverse()
  end

  defp reflexive_vertex?(%Bluetab.Graph{} = g, v) do
    g
    |> Bluetab.Graph.out_neighbours(v)
    |> Enum.member?(v)
  end
end
