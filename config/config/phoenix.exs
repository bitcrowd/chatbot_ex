import Config

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

if config_env() == :dev do
  # Set a higher stacktrace during development. Avoid configuring such
  # in production as building large stacktraces may be expensive.
  config :phoenix, :stacktrace_depth, 20

  config :phoenix_live_view,
    # Include HEEx debug annotations as HTML comments in rendered markup
    debug_heex_annotations: true
end

if config_env() in [:dev, :test] do
  # Initialize plugs at runtime for faster test compilation
  config :phoenix, :plug_init_mode, :runtime

  # Enable helpful, but potentially expensive runtime checks
  config :phoenix_live_view,
    enable_expensive_runtime_checks: true
end
