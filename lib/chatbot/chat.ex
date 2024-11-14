defmodule Chatbot.Chat do
  @moduledoc """
  Context for chat related functions.
  """
  import Ecto.Query, only: [from: 2]
  alias Chatbot.{Chat.Message, LLMMock}
  alias LangChain.Chains.LLMChain
  # There is currently a bug in the LangChain type specs:
  # `add_callback/2` expects a map with all possible handler functions.
  # See:
  # https://hexdocs.pm/langchain/0.3.0-rc.0/LangChain.Chains.ChainCallbacks.html#t:chain_callback_handler/0
  @dialyzer {:nowarn_function, stream_assistant_message: 2}

  @doc """
  Creates a message.
  """
  @spec create_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
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

  @doc """
  Sends a query containing the given messages to the LLM and
  saves the response as an assistant message.
  """
  @spec request_assistant_message([Message.t()]) ::
          {:ok, Message.t()} | {:error, String.t() | Ecto.Changeset.t()}
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

  @doc """
  Sends a query containing the given messages to the LLM and
  streams the partial responses to process with the given pid.

  Once the full message was processed, it is saved as an assistant message.
  """
  @spec stream_assistant_message([Message.t()], pid()) :: :ok
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

    :ok
  end

  defp maybe_mock_llm(opts \\ []) do
    if Application.fetch_env!(:chatbot, :mock_llm_api), do: LLMMock.mock(opts)
  end

  @doc """
  Lists all messages ordered by insertion date.
  """
  @spec all_messages() :: [Message.t()]
  def all_messages do
    Chatbot.Repo.all(from(m in Message, order_by: m.inserted_at))
  end
end
