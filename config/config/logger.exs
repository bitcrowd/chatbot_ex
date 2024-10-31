import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

if config_env() == :dev do
  # Do not include metadata nor timestamps in development logs
  config :logger, :console, format: "[$level] $message\n"
end

if config_env() == :test do
  # Print only warnings and errors during test
  config :logger, level: :warning
end

if config_env() == :prod do
  # Do not print debug messages in production
  config :logger, level: :info
end
