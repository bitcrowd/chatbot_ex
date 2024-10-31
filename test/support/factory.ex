defmodule Chatbot.Factory do
  use ExMachina.Ecto, repo: Chatbot.Repo

  def message_factory do
    %Chatbot.Chat.Message{
      role: :user,
      content: "something in a message"
    }
  end
end
