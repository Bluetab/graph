defmodule Graph.LevelGraph do
  alias Graph.Edge
  alias Graph.Vertex

  defstruct g: %Graph{}, phi: &__MODULE__.default_level_fn/2

  @type t :: %__MODULE__{g: Graph.t(), phi: level_fn}
  @type level_fn :: (Graph.t(), Vertex.id() -> pos_integer | {:error, :bad_vertex})

  @spec new(Graph.t()) :: t
  def new(g), do: %__MODULE__{g: g}

  @spec new(Graph.t(), level_fn) :: t
  def new(g, phi), do: %__MODULE__{g: g, phi: phi}

  @spec is_proper?(t) :: boolean
  def is_proper?(%__MODULE__{g: g} = lg) do
    g
    |> Graph.edges()
    |> Enum.all?(&(span(lg, &1) == 1))
  end

  @spec level(t, Vertex.id()) :: pos_integer | {:error, :bad_vertex}
  def level(%__MODULE__{g: g, phi: phi}, vertex_id) do
    case Graph.vertex(g, vertex_id) do
      nil -> {:error, :bad_vertex}
      _v -> phi.(g, vertex_id)
    end
  end

  @spec span(t, Edge.id()) :: pos_integer | {:error, :bad_edge}
  def span(lg, edge_or_id)

  def span(%__MODULE__{} = lg, %Edge{v1: u, v2: v}) do
    with phi_v when is_integer(phi_v) <- level(lg, v),
         phi_u when is_integer(phi_u) <- level(lg, u) do
      phi_v - phi_u
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
  @spec vertices_by_level(t) :: %{pos_integer: [Vertex.id()]}
  def vertices_by_level(%__MODULE__{g: g} = lg) do
    g
    |> Graph.vertices()
    |> Enum.group_by(&level(lg, &1))
  end

  @doc """
  Returns the vertices of a given level of a k-level graph.
  """
  @spec vertices_by_level(t, pos_integer) :: [Vertex.id()]
  def vertices_by_level(%__MODULE__{g: g} = lg, level) do
    g
    |> Graph.vertices()
    |> Enum.filter(&(level(lg, &1) == level))
  end
end
