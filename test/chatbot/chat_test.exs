defmodule Chatbot.ChatTest do
  use Chatbot.DataCase
  import Chatbot.Factory

  alias Chatbot.Chat

  describe "create_message/1" do
    test "creates a message" do
      params = params_for(:message)

      assert {:ok, %Chat.Message{}} = Chat.create_message(params)
    end

    test "returns an error when given invalid params" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(%{})
    end

    test "creates message with empty content string" do
      params = params_for(:message, content: "")

      assert {:ok, %Chat.Message{content: ""}} = Chat.create_message(params)
    end
  end

  describe "update_message!/2" do
    test "updates a message when given valid params" do
      message = insert(:message)

      assert %{content: "New content"} =
               Chat.update_message!(message, %{content: "New content"})
    end

    test "raises when given invalid params" do
      message = insert(:message)

      assert_raise Ecto.InvalidChangesetError, fn ->
        Chat.update_message!(message, %{role: "invalid"})
      end
    end
  end

  describe "all_messages/0" do
    test "returns all messages sorted by inserted_at" do
      now = DateTime.utc_now()
      latest_message = insert(:message, inserted_at: now)
      older_message = insert(:message, inserted_at: DateTime.add(now, -1, :day))

      assert Chat.all_messages() == [older_message, latest_message]
    end
  end

  describe "delete_all_messages/0" do
    test "deletes all messages" do
      insert(:message, role: :user)
      insert(:message, role: :assistant)

      assert Chat.delete_all_messages() == :ok

      assert Repo.all(Chat.Message) == []
    end
  end

  describe "request_assistant_message/0" do
    test "returns assistant message" do
      insert(:message, role: :user)

      assert {:ok, message} = Chat.request_assistant_message()

      assert message.role == :assistant
      assert message.content =~ "Thanks for your question"
    end
  end

  describe "stream_assistant_message/1" do
    test "returns empty assistant message and streams message deltas" do
      insert(:message, role: :user)

      assert {:ok, message} = Chat.stream_assistant_message(self())

      assert message.role == :assistant
      assert message.content == ""
      message_id = message.id

      assert_receive({:next_message_delta, ^message_id, %{content: nil, status: :incomplete}})

      assert_receive(
        {:next_message_delta, ^message_id,
         %{content: "Thanks for your question. ", status: :incomplete}}
      )

      assert_receive(
        {:next_message_delta, ^message_id,
         %{content: "Let me think about that. ", status: :incomplete}}
      )

      assert_receive({:next_message_delta, ^message_id, %{content: "... ", status: :incomplete}})

      assert_receive(
        {:next_message_delta, ^message_id,
         %{content: "I don't have an answer right now. ", status: :incomplete}}
      )

      assert_receive(
        {:next_message_delta, ^message_id,
         %{content: "Please try another question. Maybe I can help with that.", status: :complete}}
      )

      assert_receive(
        {:message_processed,
         %Chat.Message{
           content:
             "Thanks for your question. Let me think about that. ... I don't have an answer right now. Please try another question. Maybe I can help with that.",
           role: :assistant
         }}
      )

      assert Repo.reload(message).content ==
               "Thanks for your question. Let me think about that. ... I don't have an answer right now. Please try another question. Maybe I can help with that."
    end
  end
end
