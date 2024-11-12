defmodule Chatbot.Chat.MessageTest do
  use Chatbot.DataCase
  alias Chatbot.Chat.Message

  describe "changeset/2" do
    test "is valid with valid params" do
      params = %{"role" => "user", "content" => "hello"}

      assert_changeset_valid(Message.changeset(params))
    end

    test "is invalid with invalid role" do
      %{"role" => "invalid role", "content" => "hello"}
      |> Message.changeset()
      |> assert_error_on(:role, "is invalid")
    end
  end
end
