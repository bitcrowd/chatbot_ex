import Config

defmodule RuntimeConfig do
  def get(envvar, opts \\ []) do
    value = System.get_env(envvar) || default(envvar, config_env())

    case Keyword.get(opts, :cast) do
      nil -> value
      :integer -> value && String.to_integer(value)
      :boolean -> value in ["1", "true", "TRUE", true]
    end
  end

  defp default("DATABASE_URL", :dev), do: "ecto://postgres:postgres@localhost/chatbot_dev"
  defp default("DATABASE_URL", :test), do: "ecto://postgres:postgres@localhost/chatbot_test"

  defp default("POOL_SIZE", :dev), do: "10"
  defp default("POOL_SIZE", :test), do: "#{System.schedulers_online() * 2}"

  defp default("ECTO_IPV6", _env), do: false

  defp default("PUBLIC_PORT", :dev), do: "4000"
  defp default("PUBLIC_PORT", :test), do: "4002"
  defp default("PUBLIC_PORT", :prod), do: "443"

  defp default("PUBLIC_HOST", env) when env in [:dev, :test], do: "localhost"
  defp default("PUBLIC_HOST", :prod), do: "example.com"

  defp default("PUBLIC_SCHEME", :prod), do: "https"
  defp default("PUBLIC_SCHEME", _), do: "http"

  defp default("SECRET_KEY_BASE", :dev),
    do: "HIOGpSCkjfoq95e9q5Rv3pjU3Bvte3d5FRrbeRLv+As8qsnp/RoVA8HdWiZqhqn/"

  defp default("SECRET_KEY_BASE", :test),
    do: "NHgNm7jZGvzNpCBY+KTT0LE3sQe7eqStsMLQGwoAOC8Hz2xFhsXPnLmf1G2l2wZI"

  defp default("DNS_CLUSTER_QUERY", _env), do: nil

  defp default("MOCK_LLM_API", :test), do: true
  defp default("MOCK_LLM_API", _env), do: false

  defp default(key, env),
    do: raise("environment variable #{key} not set and no default for #{inspect(env)}")
end

# --------------------------------- Database -------------------------------------

socket_options =
  case RuntimeConfig.get("ECTO_IPV6", cast: :boolean) do
    true -> [:inet6]
    _ -> []
  end

config :chatbot, Chatbot.Repo,
  # ssl: true,
  url: RuntimeConfig.get("DATABASE_URL"),
  pool_size: RuntimeConfig.get("POOL_SIZE", cast: :integer),
  socket_options: socket_options

# --------------------------------- Endpoint -------------------------------------

public_url_opts = [
  scheme: RuntimeConfig.get("PUBLIC_SCHEME"),
  host: RuntimeConfig.get("PUBLIC_HOST"),
  port: RuntimeConfig.get("PUBLIC_PORT", cast: :integer),
  path: "/"
]

config :chatbot, ChatbotWeb.Endpoint,
  secret_key_base: RuntimeConfig.get("SECRET_KEY_BASE"),
  url: public_url_opts

# --------------------------------- Misc -------------------------------------

config :chatbot, :dns_cluster_query, RuntimeConfig.get("DNS_CLUSTER_QUERY")

config :chatbot, :mock_llm_api, RuntimeConfig.get("MOCK_LLM_API", cast: :boolean)
