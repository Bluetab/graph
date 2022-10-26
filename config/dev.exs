import Config

config :logger, :console,
  level: :debug,
  metadata: [:pid, :module]
