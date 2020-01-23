defmodule Graph.LevelGraph do
  @moduledoc """
  **Forster (2005):**
  > **(Level Graph)**: A k-**level graph** $G = (V, E, Phi)$ is a graph $(V, E)$
  > with a **leveling** $Phi: V -> {1,...,k}$ that partitions the vertex set
  > into k disjoint levels $V_1, ..., V_k, V_i = Phi^(−1)(i)$, such that each
  > edge $(u, v) in E$ has a positive **span** $Phi(v) − Phi(u) > 0$, i.e., all
  > edges point downwards. Edges are called **proper** if their span is 1 and
  > **long span** edges otherwise. $G$ is proper if all its edges are proper.
  """
  alias Graph.Edge
  alias Graph.Vertex

  defstruct g: %Graph{}, phi: &__MODULE__.default_level_fn/2

  @type t :: %__MODULE__{g: Graph.t(), phi: level_fn}
  @type vertex :: Vertex.id()
  @type level :: pos_integer
  @type level_fn :: (Graph.t(), vertex -> level | {:error, :bad_vertex})
  @type direction :: :left | :right

  @spec new(Graph.t()) :: t
  def new(g), do: %__MODULE__{g: g}

  @spec new(Graph.t(), level_fn) :: t
  def new(g, phi) when is_function(phi), do: %__MODULE__{g: g, phi: phi}

  @spec new(Graph.t(), atom) :: t
  def new(g, label) when is_atom(label) do
    case phi(label) do
      phi when is_function(phi) -> new(g, phi)
    end
  end

  @spec phi(atom) :: level_fn
  def phi(label) when is_atom(label), do: fn g, v -> Graph.vertex(g, v, label) end

  @spec subgraph(t, [level]) :: t
  def subgraph(%__MODULE__{g: g} = lg, levels) do
    vs =
      lg
      |> vertices_by_level()
      |> Map.take(levels)
      |> Map.values()
      |> Enum.flat_map(& &1)

    %{lg | g: Graph.subgraph(g, vs)}
  end

  @spec is_proper?(t) :: boolean
  def is_proper?(%__MODULE__{g: g} = lg) do
    g
    |> Graph.edges()
    |> Enum.all?(&(span(lg, &1) == 1))
  end

  @spec level(t, vertex) :: level | {:error, :bad_vertex}
  def level(%__MODULE__{g: g, phi: phi}, vertex_id) do
    case Graph.vertex(g, vertex_id) do
      nil -> {:error, :bad_vertex}
      _v -> phi.(g, vertex_id)
    end
  end

  @spec span(t, Edge.id()) :: level | {:error, :bad_edge}
  def span(lg, edge_or_id)

  def span(%__MODULE__{} = lg, %Edge{v1: u, v2: v}) do
    with phi_v when is_integer(phi_v) <- level(lg, v),
         phi_u when is_integer(phi_u) <- level(lg, u) do
      abs(phi_v - phi_u)
    else
      _ -> {:error, :bad_edge}
    end
  end

  def span(%__MODULE__{g: g} = lg, edge_id) do
    case Graph.edge(g, edge_id) do
      nil -> {:error, :bad_edge}
      e -> span(lg, e)
    end
  end

  def default_level_fn(%Graph{} = g, v) do
    case Graph.in_degree(g, v) do
      0 -> 1
      _ -> 2
    end
  end

  @doc """
  Returns a map whose keys are levels and whose values are lists of vertices at
  each level.
  """
  @spec vertices_by_level(t) :: %{level: [vertex]}
  def vertices_by_level(%__MODULE__{g: g} = lg) do
    g
    |> Graph.vertices()
    |> Enum.sort_by(&Graph.vertex(g, &1, :b))
    |> Enum.group_by(&level(lg, &1))
  end

  @spec predecessor_map(t, direction) :: %{vertex: vertex}
  def predecessor_map(%__MODULE__{} = lg, direction \\ :left) do
    lg
    |> vertices_by_level()
    |> Enum.flat_map(fn {_, vs} -> Enum.chunk_every(vs, 2, 1, :discard) end)
    |> Map.new(pred_transform(direction))
  end

  defp pred_transform(:left), do: fn [v1, v2] -> {v2, v1} end
  defp pred_transform(:right), do: fn [v1, v2] -> {v1, v2} end

  @doc """
  Returns the vertices of a given level of a k-level graph.
  """
  @spec vertices_by_level(t, level) :: [vertex]
  def vertices_by_level(%__MODULE__{g: g} = lg, level) do
    g
    |> Graph.vertices()
    |> Enum.filter(&(level(lg, &1) == level))
  end

  @doc """
  Returns the edges of a k-level graph having span greater than 1.
  """
  @spec long_span_edges(t) :: [Edge.t()]
  def long_span_edges(%__MODULE__{g: g} = lg) do
    g
    |> Graph.get_edges()
    |> Enum.filter(&(span(lg, &1) > 1))
  end

  @doc """
  Initializes the position of each vertex in a k-level graph by assigning a
  value to a given `label`.
  """
  @spec initialize_pos(t) :: t
  def initialize_pos(%__MODULE__{g: g} = lg, label \\ :b) do
    g =
      lg
      |> vertices_by_level()
      |> Enum.flat_map(fn {_, vs} -> Enum.with_index(vs, 1) end)
      |> Enum.reduce(g, fn {v, b}, acc -> Graph.put_label(acc, v, %{label => b}) end)

    %{lg | g: g}
  end

  @doc """
  Associates `labels` with a vertex of a level graph.
  """
  @spec put_label(t, vertex, Enumerable.t()) :: t
  def put_label(%__MODULE__{g: g} = lg, v, labels) do
    %{lg | g: Graph.put_label(g, v, labels)}
  end

  @doc """
  Returns the cross count of a k-level graph.
  """
  @spec cross_count(t) :: non_neg_integer
  def cross_count(%__MODULE__{g: g} = lg) do
    alias Graph.CrossCount

    lg
    |> vertices_by_level()
    |> Map.keys()
    |> Enum.sort()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(&subgraph(lg, &1))
    |> Enum.map(&CrossCount.bilayer_cross_count(&1.g, fn v -> Graph.vertex(g, v, :b) end))
    |> Enum.sum()
  end

  defimpl Inspect do
    import Inspect.Algebra

    alias Graph.LevelGraph

    def inspect(%LevelGraph{} = lg, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      levels = LevelGraph.vertices_by_level(lg)
      concat(["#LevelGraph<", Inspect.Map.inspect(levels, opts), ">"])
    end
  end
end
