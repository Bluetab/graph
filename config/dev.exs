use Mix.Config

config :logger, :console,
  level: :debug,
  metadata: [:pid, :module]
