defmodule Chatbot.Chat do
  @moduledoc """
  Context for chat related functions.
  """
  import Ecto.Query, only: [from: 2]
  alias Chatbot.{Chat.Message, Repo}
  alias LangChain.Chains.LLMChain
  # There is currently a bug in the LangChain type specs:
  # `add_callback/2` expects a map with all possible handler functions.
  # See:
  # https://hexdocs.pm/langchain/0.3.0-rc.0/LangChain.Chains.ChainCallbacks.html#t:chain_callback_handler/0
  @dialyzer {:nowarn_function, stream_assistant_message: 3}

  @doc """
  Creates a message.
  """
  @spec create_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def create_message(attrs) do
    attrs
    |> Message.changeset()
    |> Repo.insert()
  end

  def update_message!(message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update!()
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
    messages = Enum.map(messages, &to_langchain_message/1)

    @chain
    |> LLMChain.add_messages(messages)
    |> LLMChain.run()
    |> case do
      {:ok, chain} ->
        create_message(%{role: :assistant, content: chain.last_message.content})

      _error ->
        {:error, "I failed, I'm sorry"}
    end
  end

  @doc """
  Sends a query containing the given messages to the LLM and
  streams the partial responses to process with the given pid.

  Once the full message was processed, it is saved as an assistant message.
  """
  @spec stream_assistant_message(pid(), [Message.t()], Message.t()) :: Message.t()
  def stream_assistant_message(receiver, messages, assistant_message) do
    messages = Enum.map(messages, &to_langchain_message/1) |> dbg()

    handler = %{
      on_llm_new_delta: fn _model, %LangChain.MessageDelta{} = data ->
        send(receiver, {:next_message_delta, assistant_message, data})
      end,
      on_message_processed: fn _chain, %LangChain.Message{} = data ->
        completed_message = update_message!(assistant_message, %{content: data.content})

        send(receiver, {:message_processed, completed_message})
      end
    }

    @chain
    |> LLMChain.add_callback(handler)
    |> LLMChain.add_llm_callback(handler)
    |> LLMChain.add_messages(messages)
    |> LLMChain.run()
  end

  def to_langchain_message(%{role: :user, content: content}),
    do: LangChain.Message.new_user!(content)

  def to_langchain_message(%{role: :assistant, content: content}),
    do: LangChain.Message.new_assistant!(content)

  @doc """
  Lists all messages ordered by insertion date.
  """
  @spec all_messages :: [Message.t()]
  def all_messages do
    Repo.all(from(m in Message, order_by: m.inserted_at))
  end

  @spec delete_all_messages :: :ok
  def delete_all_messages do
    {_count, nil} = Repo.delete_all(Message)
    :ok
  end
end
