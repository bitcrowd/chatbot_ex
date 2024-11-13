defmodule Chatbot.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Chatbot.Repo

  def message_factory do
    %Chatbot.Chat.Message{
      role: :user,
      content: "something in a message"
    }
  end
end
