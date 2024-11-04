defmodule Chatbot.Chat.MessageTest do
  use Chatbot.DataCase
  import Chatbot.Factory
  alias Chatbot.Chat.Message

  describe "table constraints" do
    test "role is not nullable" do
      assert_raise Postgrex.Error, ~r/null value in column "role"/, fn ->
        insert(:message, role: nil)
      end
    end

    test "content is not nullable" do
      assert_raise Postgrex.Error, ~r/null value in column "content"/, fn ->
        insert(:message, content: nil)
      end
    end
  end

  describe "changeset/2" do
    test "is valid with valid params" do
      params = %{"role" => "user", "content" => "hello"}

      assert_changeset_valid(Message.changeset(params))
    end

    test "is valid with empty string content" do
      params = %{"role" => "user", "content" => ""}

      assert_changeset_valid(Message.changeset(params))
    end

    test "is invalid with invalid role" do
      %{"role" => "invalid role", "content" => "hello"}
      |> Message.changeset()
      |> assert_error_on(:role, "is invalid")
    end

    test "requires role" do
      %{}
      |> Message.changeset()
      |> assert_required_error_on(:role)
    end
  end
end
