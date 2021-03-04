defmodule Graph do
  @moduledoc """
  Represents a directed graph. Borrows heavily from the OTP `digraph` module.
  """

  alias Graph.Edge
  alias Graph.Traversal
  alias Graph.Vertex

  defstruct vertices: %{}, edges: %{}, in_edges: %{}, out_edges: %{}, opts: []

  @type t :: %__MODULE__{
          vertices: %{vertex_id: Vertex.label()} | %{},
          edges: %{edge_id: edge_entry} | %{},
          in_edges: vertex_edges | %{},
          out_edges: vertex_edges | %{},
          opts: Keyword.t()
        }
  @type id :: any
  @typep edge_id :: Edge.id()
  @typep edge_entry :: {vertex_id, vertex_id, Edge.label()}
  @typep vertex_id :: Vertex.id()
  @typep vertex_edges :: %{vertex_id: MapSet.t()}

  @doc """
  Returns an empty graph.

    ## Examples

      iex> Graph.new()
      %Graph{}

  """
  @spec new :: t
  def new, do: %__MODULE__{}

  @doc """
  Returns a new graph with a given set of initial `vertices`. If `vertices` is
  a keyword list or a map, the keys are used as the vertex ids and the values
  are used as the label.

    ## Examples

      iex> g = Graph.new([:foo, :bar])
      iex> Graph.vertices(g)
      [:bar, :foo]

      iex> g = Graph.new(%{foo: [w: 0], bar: [w: 1]})
      iex> Graph.vertices(g)
      [:bar, :foo]

      iex> g = Graph.new([foo: %{w: 0}, bar: []])
      iex> Graph.vertices(g)
      [:bar, :foo]

  """
  @spec new(Enumerable.t() | t, Keyword.t()) :: t
  def new(enumerable_or_graph, opts \\ [])

  def new(%__MODULE__{} = g, opts) do
    if Keyword.get(opts, :edges, true) do
      %{g | opts: opts}
    else
      %{g | edges: %{}, in_edges: %{}, out_edges: %{}, opts: opts}
    end
  end

  def new(%{} = vertices, opts) do
    Enum.reduce(vertices, %__MODULE__{opts: opts}, fn {v, label}, g -> add_vertex(g, v, label) end)
  end

  def new(vertices, opts) when is_list(vertices) do
    if Keyword.keyword?(vertices) do
      new(Map.new(vertices), opts)
    else
      Enum.reduce(vertices, %__MODULE__{opts: opts}, fn v, g -> add_vertex(g, v) end)
    end
  end

  @doc """
  Adds or replaces a vertex in a graph.

    ## Examples

      iex> g = Graph.new()
      iex> Graph.add_vertex(g, :foo)
      %Graph{vertices: %{foo: %{}}}

  """
  @spec add_vertex(t, vertex_id, Enumerable.t()) :: t
  def add_vertex(g, vertex_id, label \\ %{})

  def add_vertex(%__MODULE__{vertices: vertices} = g, id, %{} = label) do
    if has_vertex?(g, id) and label == %{} do
      g
    else
      %{g | vertices: Map.put(vertices, id, label)}
    end
  end

  def add_vertex(%__MODULE__{} = g, id, label) when is_list(label) do
    add_vertex(g, id, Map.new(label))
  end

  @doc """
  Removes a vertex from a graph, if it exists.

    ## Examples

      iex> g = Graph.new(foo: [w: 0], bar: [w: 1])
      iex> Graph.del_vertex(g, :foo)
      %Graph{vertices: %{bar: %{w: 1}}}

  """
  @spec del_vertex(t, vertex_id) :: t
  def del_vertex(%__MODULE__{} = g, v) do
    do_del_vertex(g, v)
  end

  @spec del_vertices(t, [vertex_id]) :: t
  def del_vertices(%__MODULE__{} = g, vs) when is_list(vs) do
    Enum.reduce(vs, g, fn v, g -> del_vertex(g, v) end)
  end

  @spec put_label(t, vertex_id, Enumerable.t()) :: t
  def put_label(g, id, label)

  def put_label(%__MODULE__{} = g, id, label) when is_list(label) do
    put_label(g, id, Map.new(label))
  end

  def put_label(%__MODULE__{vertices: vertices} = g, id, %{} = label) do
    if Map.has_key?(vertices, id) do
      label =
        vertices
        |> Map.get(id)
        |> Map.merge(label)

      %{g | vertices: Map.put(vertices, id, label)}
    else
      {:error, :bad_vertex}
    end
  end

  @spec vertex(t, vertex_id) :: Vertex.t() | nil
  def vertex(%__MODULE__{vertices: vertices}, id) do
    case Map.get(vertices, id) do
      nil -> nil
      label -> %Vertex{id: id, label: label}
    end
  end

  @spec vertex_label(t, vertex_id) :: Vertex.label() | nil
  def vertex_label(%__MODULE__{vertices: vertices}, id) do
    Map.get(vertices, id)
  end

  @spec vertex_labels(t) :: [Vertex.label()]
  def vertex_labels(%__MODULE__{vertices: vertices}) do
    Map.values(vertices)
  end

  @spec vertices(t, Keyword.t()) :: [vertex_id] | map()
  def vertices(%__MODULE__{vertices: vertices}, opts \\ []) do
    if opts[:labels], do: vertices, else: Map.keys(vertices)
  end

  @spec has_vertex?(t, vertex_id) :: boolean
  def has_vertex?(%__MODULE__{vertices: vertices}, v) do
    Map.has_key?(vertices, v)
  end

  @spec vertex(t, vertex_id, any) :: any
  def vertex(%__MODULE__{vertices: vertices}, id, l) do
    case Map.get(vertices, id) do
      nil -> nil
      label -> Map.get(label, l)
    end
  end

  @doc """
  Returns the edge of the graph with the given id, or nil if no such edge exists.

    ## Examples

      iex> g = Graph.new([:foo, :bar, :baz])
      iex> Graph.edge(g, :e1)
      nil
      iex> g = Graph.add_edge(g, :e1, :foo, :bar, w: 0)
      iex> Graph.edge(g, :e1)
      %Edge{id: :e1, v1: :foo, v2: :bar, label: %{w: 0}}

  """
  @spec edge(t, edge_id) :: Edge.t() | nil
  def edge(%__MODULE__{edges: edges}, id) do
    case Map.get(edges, id) do
      nil -> nil
      {v1, v2, label} -> %Edge{id: id, v1: v1, v2: v2, label: label}
    end
  end

  @doc """
  Returns the edges of a graph.

    ## Examples

      iex> g = Graph.new([:foo, :bar, :baz])
      iex> g = Graph.add_edge(g, :e1, :foo, :bar, %{})
      iex> Graph.edges(g)
      [:e1]

  """
  @spec edges(t) :: [edge_id]
  def edges(%__MODULE__{edges: edges}) do
    Map.keys(edges)
  end

  def get_edges(%__MODULE__{edges: edges}, transform \\ &Edge.from_entry/1) do
    Enum.map(edges, transform)
  end

  @spec add_edge(t, vertex_id, vertex_id, Enumerable.t()) :: t | {:error, any}
  def add_edge(%__MODULE__{} = g, v1, v2, label \\ %{}) do
    edge_id = random_edge_id(g)
    add_edge(g, edge_id, v1, v2, label)
  end

  @spec add_edge(t, edge_id, vertex_id, vertex_id, Enumerable.t()) :: t | {:error, any}
  def add_edge(%__MODULE__{} = g, id, v1, v2, label) do
    do_add_edge(g, {id, v1, v2, label})
  end

  @spec has_edge?(t, vertex_id, vertex_id) :: boolean | {:error, {:bad_vertex, vertex_id}}
  def has_edge?(%__MODULE__{} = g, v1, v2) do
    g
    |> out_neighbours(v1)
    |> Enum.member?(v2)
  end

  defp random_edge_id(%__MODULE__{edges: edges} = g) do
    with id <- [:_e | :rand.uniform(1_000_000)],
         false <- Map.has_key?(edges, id) do
      id
    else
      true -> random_edge_id(g)
    end
  end

  @doc """
  Adds multiple edges to a graph.

    ## Examples

      iex> g = Graph.new([:foo, :bar, :baz])
      iex> g = Graph.add_edges(g, [{:foo, :bar}, {:bar, :baz}])
      iex> Graph.out_neighbours(g, :foo)
      [:bar]
      iex> Graph.out_neighbours(g, :bar)
      [:baz]

  """
  @spec add_edges(t, Enumerable.t()) :: t
  def add_edges(g, edges)

  def add_edges(%__MODULE__{} = g, %{} = edges) do
    add_edges(g, Keyword.new(edges))
  end

  def add_edges(%__MODULE__{} = g, edges) when is_list(edges) do
    Enum.reduce(edges, g, fn {v1, v2}, g -> add_edge(g, v1, v2) end)
  end

  @spec del_edge(t, edge_id) :: t
  def del_edge(%__MODULE__{} = g, id) do
    do_del_edges(g, [id])
  end

  @spec no_vertices(t) :: non_neg_integer()
  def no_vertices(%__MODULE__{vertices: vertices}), do: Enum.count(vertices)

  @doc """
  Returns the number of edges in a graph.

    ## Examples

      iex> g = Graph.new([:foo, :bar, :baz])
      iex> g = Graph.add_edge(g, :foo, :bar)
      iex> g = Graph.add_edge(g, :bar, :baz)
      iex> g = Graph.add_edge(g, :e3, :foo, :bar, %{})
      iex> Graph.no_edges(g)
      3

  """
  @spec no_edges(t) :: non_neg_integer()
  def no_edges(%__MODULE__{edges: edges}) do
    Enum.count(edges)
  end

  @doc """
  Returns vertices with in_degree > 0.

    ## Examples

      iex> g = Graph.new([:foo, :bar, :baz])
      iex> g = Graph.add_edge(g, :foo, :bar)
      iex> g = Graph.add_edge(g, :bar, :baz)
      iex> Graph.in_vertices(g)
      [:bar, :baz]

  """
  @spec in_vertices(t) :: [vertex_id]
  def in_vertices(%__MODULE__{in_edges: in_edges}) do
    Map.keys(in_edges)
  end

  @spec source_vertices(t) :: [vertex_id]
  def source_vertices(%__MODULE__{vertices: vertices, in_edges: in_edges}) do
    vertices
    |> Map.drop(Map.keys(in_edges))
    |> Map.keys()
  end

  @spec sink_vertices(t) :: [vertex_id]
  def sink_vertices(%__MODULE__{vertices: vertices, out_edges: out_edges}) do
    vertices
    |> Map.drop(Map.keys(out_edges))
    |> Map.keys()
  end

  @spec inner_vertices(t) :: [vertex_id]
  def inner_vertices(%__MODULE__{in_edges: in_edges, out_edges: out_edges}) do
    [in_edges, out_edges]
    |> Enum.map(&Map.keys/1)
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end

  @spec degree(t, vertex_id) :: non_neg_integer() | {:error, :bad_vertex}
  def degree(%__MODULE__{} = g, v) do
    with i when is_integer(i) <- in_degree(g, v),
         o when is_integer(o) <- out_degree(g, v) do
      i + o
    else
      e -> e
    end
  end

  @spec in_degree(t, vertex_id) :: non_neg_integer() | {:error, :bad_vertex}
  def in_degree(%__MODULE__{vertices: vertices, in_edges: in_edges}, v) do
    if Map.has_key?(vertices, v) do
      in_edges
      |> Map.get(v, [])
      |> Enum.count()
    else
      {:error, :bad_vertex}
    end
  end

  @spec out_degree(t, vertex_id) :: non_neg_integer() | {:error, :bad_vertex}
  def out_degree(%__MODULE__{vertices: vertices, out_edges: out_edges}, v) do
    if Map.has_key?(vertices, v) do
      out_edges
      |> Map.get(v, [])
      |> Enum.count()
    else
      {:error, :bad_vertex}
    end
  end

  @spec in_neighbours(t, vertex_id) :: [vertex_id] | {:error, {:bad_vertex, vertex_id}}
  def in_neighbours(%__MODULE__{vertices: vertices, in_edges: in_edges} = g, v) do
    if Map.has_key?(vertices, v) do
      in_edges
      |> Map.get(v, [])
      |> Enum.map(&edge(g, &1))
      |> Enum.map(fn %Edge{v1: v1} -> v1 end)
    else
      {:error, {:bad_vertex, v}}
    end
  end

  @spec out_neighbours(t, vertex_id) :: [vertex_id] | {:error, {:bad_vertex, vertex_id}}
  def out_neighbours(%__MODULE__{vertices: vertices, out_edges: out_edges} = g, v) do
    if Map.has_key?(vertices, v) do
      out_edges
      |> Map.get(v, [])
      |> Enum.map(&edge(g, &1))
      |> Enum.map(fn %Edge{v2: v2} -> v2 end)
    else
      {:error, {:bad_vertex, v}}
    end
  end

  @spec in_edges(t, vertex_id) :: [edge_id] | {:error, :bad_vertex}
  def in_edges(%__MODULE__{vertices: vertices, in_edges: in_edges}, v) do
    if Map.has_key?(vertices, v) do
      in_edges
      |> Map.get(v, MapSet.new())
      |> MapSet.to_list()
    else
      {:error, :bad_vertex}
    end
  end

  @spec out_edges(t, vertex_id) :: [edge_id] | {:error, :bad_vertex}
  def out_edges(%__MODULE__{vertices: vertices, out_edges: out_edges}, v) do
    if Map.has_key?(vertices, v) do
      out_edges
      |> Map.get(v, MapSet.new())
      |> MapSet.to_list()
    else
      {:error, :bad_vertex}
    end
  end

  @spec is_tree(t) :: true | false
  def is_tree(%__MODULE__{} = g) do
    1 + no_edges(g) == no_vertices(g) and Enum.count(Traversal.components(g)) == 1
  end

  @spec is_arborescence(t) :: true | false
  def is_arborescence(%__MODULE__{} = g) do
    Traversal.arborescence_root(g) != nil
  end

  @spec subgraph(t, [vertex_id]) :: t
  def subgraph(
        %__MODULE__{vertices: vertices, edges: edges, in_edges: in_edges, out_edges: out_edges},
        vs,
        opts \\ []
      ) do
    vm = MapSet.new(vs)

    edge_ids =
      [in_edges, out_edges]
      |> Enum.map(&Map.take(&1, vs))
      |> Enum.flat_map(&Map.values/1)
      |> Enum.reduce(MapSet.new(), &MapSet.union/2)
      |> MapSet.to_list()

    edges
    |> Map.take(edge_ids)
    |> Enum.filter(fn {_, {v1, v2, _}} -> MapSet.member?(vm, v1) and MapSet.member?(vm, v2) end)
    |> reverse_edges(opts[:reverse])
    |> Enum.reduce(new(Map.take(vertices, vs)), fn {edge_id, {v1, v2, label}}, sg ->
      add_edge(sg, edge_id, v1, v2, label)
    end)
  end

  defp reverse_edges(edges, true) do
    Enum.map(edges, fn {edge_id, {v1, v2, label}} -> {edge_id, {v2, v1, label}} end)
  end

  defp reverse_edges(edges, _false), do: edges

  @spec do_del_vertex(t, vertex_id) :: t
  defp do_del_vertex(%__MODULE__{vertices: vs, edges: edges}, v) do
    vs = Map.delete(vs, v)

    edges
    |> Enum.reject(fn {_, {v1, v2, _}} -> v1 == v or v2 == v end)
    |> Enum.reduce(new(vs), fn {edge_id, {v1, v2, label}}, sg ->
      add_edge(sg, edge_id, v1, v2, label)
    end)
  end

  @spec do_del_edges(t, [edge_id]) :: t
  defp do_del_edges(g, edge_ids)

  defp do_del_edges(
         %__MODULE__{edges: edges, in_edges: in_edges, out_edges: out_edges} = g,
         [id | ids]
       ) do
    case Map.get(edges, id) do
      nil ->
        g

      {v1, v2, _} ->
        v1n = out_edges |> Map.get(v1, MapSet.new()) |> MapSet.delete(id)
        v2n = in_edges |> Map.get(v2, MapSet.new()) |> MapSet.delete(id)

        g = %{
          g
          | in_edges:
              if MapSet.size(v2n) == 0 do
                Map.delete(in_edges, v2)
              else
                Map.put(in_edges, v2, v2n)
              end,
            out_edges:
              if MapSet.size(v1n) == 0 do
                Map.delete(out_edges, v1)
              else
                Map.put(out_edges, v1, v1n)
              end,
            edges: Map.delete(edges, id)
        }

        do_del_edges(g, ids)
    end
  end

  defp do_del_edges(%__MODULE__{} = g, []), do: g

  @spec do_add_edge(t, {edge_id, vertex_id, vertex_id, Keyword.t()}) :: t | {:error, any}
  defp do_add_edge(%__MODULE__{} = g, {id, v1, v2, label}) when is_list(label) do
    do_add_edge(g, {id, v1, v2, Map.new(label)})
  end

  @spec do_add_edge(t, {edge_id, vertex_id, vertex_id, map}) :: t | {:error, any}
  defp do_add_edge(%__MODULE__{vertices: vs, opts: opts} = g, {id, v1, v2, label}) do
    with true <- Map.has_key?(vs, v1),
         true <- Map.has_key?(vs, v2),
         false <- other_edge_exists?(g, id, v1, v2) do
      if opts[:acyclic] do
        acyclic_add_edge(g, {id, v1, v2, label})
      else
        do_insert_edge(g, {id, v1, v2, label})
      end
    else
      false -> {:error, :bad_vertex}
      true -> {:error, :bad_edge}
    end
  end

  @spec other_edge_exists?(t, edge_id, vertex_id, vertex_id) :: true | false
  defp other_edge_exists?(%__MODULE__{} = g, id, v1, v2) do
    case edge(g, id) do
      nil -> false
      %Edge{v1: ^v1, v2: ^v2} -> false
      _ -> true
    end
  end

  @spec do_insert_edge(t, {edge_id, vertex_id, vertex_id, map}) :: t
  defp do_insert_edge(
         %__MODULE__{edges: es, in_edges: ins, out_edges: outs} = g,
         {id, v1, v2, label}
       ) do
    v1n = outs |> Map.get(v1, MapSet.new()) |> MapSet.put(id)
    v2n = ins |> Map.get(v2, MapSet.new()) |> MapSet.put(id)

    %{
      g
      | edges: Map.put(es, id, {v1, v2, label}),
        in_edges: Map.put(ins, v2, v2n),
        out_edges: Map.put(outs, v1, v1n)
    }
  end

  @spec get_path(t, vertex_id, vertex_id) :: [vertex_id] | false
  def get_path(%__MODULE__{} = g, v1, v2) do
    one_path(out_neighbours(g, v1), v2, [], [v1], [v1], 1, g, 1)
  end

  @spec del_path(t, vertex_id, vertex_id) :: t
  def del_path(%__MODULE__{} = g, v1, v2) do
    case get_path(g, v1, v2) do
      false ->
        g

      path ->
        g
        |> rm_edges(path)
        |> del_path(v1, v2)
    end
  end

  @spec get_cycle(t, vertex_id) :: [vertex_id] | nil
  def get_cycle(%__MODULE__{} = g, v) do
    case out_neighbours(g, v) do
      {:error, e} ->
        {:error, e}

      ws ->
        case one_path(ws, v, [], [v], [v], 2, g, 1) do
          false -> if Enum.member?(ws, v), do: [v], else: false
          vs -> vs
        end
    end
  end

  @spec rm_edges(t, [vertex_id]) :: t
  defp rm_edges(%__MODULE__{edges: edges} = g, [v1, v2 | vs]) do
    edge_ids =
      edges
      |> Map.take(out_edges(g, v1))
      |> Enum.filter(fn {_, {_, w, _}} -> w == v2 end)
      |> Enum.map(fn {e, _} -> e end)

    g
    |> do_del_edges(edge_ids)
    |> rm_edges([v2 | vs])
  end

  defp rm_edges(%__MODULE__{} = g, _), do: g

  defp one_path([w | ws], w, cont, xs, ps, prune, %__MODULE__{} = g, counter) do
    case prune_short_path(counter, prune) do
      :short -> one_path(ws, w, cont, xs, ps, prune, g, counter)
      :ok -> Enum.reverse([w | ps])
    end
  end

  defp one_path([v | vs], w, cont, xs, ps, prune, %__MODULE__{} = g, counter) do
    case Enum.member?(xs, v) do
      true ->
        one_path(vs, w, cont, xs, ps, prune, g, counter)

      false ->
        one_path(
          out_neighbours(g, v),
          w,
          [{vs, ps} | cont],
          [v | xs],
          [v | ps],
          prune,
          g,
          counter + 1
        )
    end
  end

  defp one_path([], w, [{vs, ps} | cont], xs, _, prune, g, counter) do
    one_path(vs, w, cont, xs, ps, prune, g, counter - 1)
  end

  defp one_path([], _, [], _, _, _, _, _counter), do: false

  @spec acyclic_add_edge(t, {edge_id, vertex_id, vertex_id, map}) ::
          t | {:error, {:bad_edge, [vertex_id]}}
  defp acyclic_add_edge(g, edge_attrs)

  defp acyclic_add_edge(%__MODULE__{}, {_e, v1, v2, _label}) when v1 == v2,
    do: {:error, {:bad_edge, [v1, v2]}}

  defp acyclic_add_edge(%__MODULE__{} = g, {e, v1, v2, label}) do
    case get_path(g, v2, v1) do
      false -> do_insert_edge(g, {e, v1, v2, label})
      path -> {:error, {:bad_edge, path}}
    end
  end

  defp prune_short_path(counter, min) when counter < min, do: :short
  defp prune_short_path(_counter, _min), do: :ok

  @spec get_short_cycle(t, vertex_id) :: false | [vertex_id]
  def get_short_cycle(%__MODULE__{} = g, v), do: get_short_path(g, v, v)

  @spec get_short_path(t, vertex_id, vertex_id) :: false | [vertex_id]
  def get_short_path(%__MODULE__{} = g, v1, v2) do
    v1
    |> queue_out_neighbours(g, :queue.new())
    |> spath(g, v2, new([v1]))
  end

  @spec spath(:queue.queue(edge_id), t, vertex_id, t) :: false | [vertex_id]
  defp spath(q, %__MODULE__{edges: edges} = g, sink, %__MODULE__{vertices: vs} = t) do
    case :queue.out(q) do
      {{:value, e}, q1} ->
        {v1, v2, _label} = Map.get(edges, e)

        if sink == v2 do
          follow_path(v1, t, [v2])
        else
          case Map.has_key?(vs, v2) do
            false ->
              t =
                t
                |> add_vertex(v2)
                |> add_edge(v2, v1)

              v2
              |> queue_out_neighbours(g, q1)
              |> spath(g, sink, t)

            _v ->
              spath(q1, g, sink, t)
          end
        end

      {:empty, _q1} ->
        false
    end
  end

  @spec follow_path(vertex_id, t, [vertex_id]) :: [vertex_id]
  defp follow_path(v, %__MODULE__{} = t, p) do
    p1 = [v | p]

    case out_neighbours(t, v) do
      [] -> p1
      [n] -> follow_path(n, t, p1)
    end
  end

  @spec queue_out_neighbours(vertex_id, t, :queue.queue(edge_id)) :: :queue.queue(edge_id)
  defp queue_out_neighbours(v, g, q0) do
    g
    |> out_edges(v)
    |> List.foldl(q0, fn e, q -> :queue.in(e, q) end)
  end

  def is_acyclic?(%__MODULE__{} = g) do
    Traversal.loop_vertices(g) == [] and Traversal.topsort(g) != false
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Graph{vertices: vs}, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["#Graph<", Inspect.List.inspect(Map.keys(vs), opts), ">"])
    end
  end
end
