defmodule Chatbot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Nx.Serving,
       [
         serving: Chatbot.Rag.Serving.build_embedding_serving(),
         name: Rag.EmbeddingServing,
         batch_timeout: 100
       ]},
      {Task.Supervisor, name: Chatbot.TaskSupervisor},
      ChatbotWeb.Telemetry,
      Chatbot.Repo,
      {DNSCluster, query: Application.get_env(:chatbot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Chatbot.PubSub},
      # Start a worker by calling: Chatbot.Worker.start_link(arg)
      # {Chatbot.Worker, arg},
      # Start to serve requests, typically the last entry
      ChatbotWeb.Endpoint
    ]

    :ok =
      :telemetry.attach_many(
        "rag-handler",
        Rag.Telemetry.events(),
        &Chatbot.Rag.TelemetryHandler.handle_event/4,
        nil
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chatbot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatbotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
