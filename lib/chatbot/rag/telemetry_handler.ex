defmodule Chatbot.Rag.TelemetryHandler do
  alias Phoenix.PubSub

  def handle_event(prefix, _measurement, _metadata, _config) do
    [:rag, key, event] = prefix
    PubSub.broadcast(Chatbot.PubSub, "rag", {key, event})
  end
end
