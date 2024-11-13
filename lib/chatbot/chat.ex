defmodule Chatbot.Chat do
  @moduledoc """
  Context for chat related functions.
  """
  import Ecto.Query, only: [from: 2]
  alias Chatbot.{Chat.Message, LLMMock}
  alias LangChain.Chains.LLMChain

  def create_message(attrs) do
    attrs
    |> Message.changeset()
    |> Chatbot.Repo.insert()
  end

  @llm LangChain.ChatModels.ChatOpenAI.new!(%{
         model: "gpt-4o-mini",
         stream: true
       })

  @chain LLMChain.new!(%{llm: @llm})
         |> LLMChain.add_message(LangChain.Message.new_system!("You give fun responses."))

  def request_assistant_message(messages) do
    maybe_mock_llm()

    messages =
      Enum.map(messages, fn %{role: role, content: content} ->
        case role do
          :user -> LangChain.Message.new_user!(content)
          :assistant -> LangChain.Message.new_assistant!(content)
        end
      end)

    @chain
    |> LLMChain.add_messages(messages)
    |> LLMChain.run()
    |> case do
      {:ok, _chain, response} ->
        create_message(%{role: :assistant, content: response.content})

      _error ->
        {:error, "I failed, I'm sorry"}
    end
  end

  def stream_assistant_message(messages, receiver) do
    handler = %{
      on_llm_new_delta: fn _model, %LangChain.MessageDelta{} = data ->
        send(receiver, {:next_message_delta, data.content})
      end,
      on_message_processed: fn _chain, %LangChain.Message{} = data ->
        create_message(%{role: :assistant, content: data.content})
        send(receiver, {:message_processed, data.content})
      end
    }

    messages =
      Enum.map(messages, fn %{role: role, content: content} ->
        case role do
          :user -> LangChain.Message.new_user!(content)
          :assistant -> LangChain.Message.new_assistant!(content)
        end
      end)

    Task.Supervisor.start_child(Chatbot.TaskSupervisor, fn ->
      maybe_mock_llm(stream: true)

      @chain
      |> LLMChain.add_callback(handler)
      |> LLMChain.add_llm_callback(handler)
      |> LLMChain.add_messages(messages)
      |> LLMChain.run()
    end)
  end

  defp maybe_mock_llm(opts \\ []) do
    if Application.fetch_env!(:chatbot, :mock_llm_api), do: LLMMock.mock(opts)
  end

  def all_messages do
    Chatbot.Repo.all(from(m in Message, order_by: m.inserted_at))
  end
end
