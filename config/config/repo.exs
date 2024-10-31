import Config

config :chatbot,
  ecto_repos: [Chatbot.Repo],
  generators: [timestamp_type: :utc_datetime]

if config_env() == :dev do
  config :chatbot, Chatbot.Repo,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
end

if config_env() == :test do
  config :chatbot, Chatbot.Repo, pool: Ecto.Adapters.SQL.Sandbox
end
