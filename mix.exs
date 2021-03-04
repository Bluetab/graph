defmodule Graph.MixProject do
  use Mix.Project

  defp mathjax_resources(:html) do
    """
    <script>
    MathJax = {
      loader: {
        load: ['input/asciimath', 'output/chtml']
      },
      asciimath: {
        delimiters: [['$','$'], ['`','`']]
      }
    }
    </script>
    <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
    <script type="text/javascript" id="MathJax-script" async
      src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/startup.js">
    </script>
    """
  end

  def project do
    [
      app: :graph,
      version: "1.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Graph",
      source_url: "https://github.com/Bluetab/graph",
      homepage_url: "https://github.com/Bluetab/graph",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "Graph",
      extras: ["README.md"],
      before_closing_body_tag: &mathjax_resources/1
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:jason, "~> 1.0"}
    ]
  end
end
