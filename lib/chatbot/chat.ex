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

  # @llm LangChain.ChatModels.ChatOllamaAI.new!(%{
  #        model: "gemma3:4b",
  #        stream: false
  #      })

  @system_prompt """
  You are an expert in Elixir programming with in-depth knowledge of Elixir.
  Provide accurate information based on the provided context to assist Elixir
  developers. Include code snippets and examples to illustrate your points.
  Respond in a professional yet approachable manner.
  Be concise for straightforward queries, but elaborate when necessary to
  ensure clarity and understanding. Adapt your responses to the complexity of
  the question. For basic usage, provide clear examples. For advanced topics,
  offer detailed explanations and multiple solutions if applicable.
  Include references to official documentation or reliable sources to support
  your answers. Ensure information is current, reflecting the latest updates
  in the library. If the context does not provide enough information, state
  this in your answer and keep it short. If you are unsure what kind of
  information the user needs, please ask follow-up questions.
  """

  @llm LangChain.ChatModels.ChatOpenAI.new!(%{
         endpoint: "https://api.groq.com/openai/v1/chat/completions",
         api_key: "",
         # model: "gemma2-9b-it",
         model: "qwen-2.5-coder-32b",
         stream: false
       })

  @chain LLMChain.new!(%{llm: @llm})
         |> LLMChain.add_message(LangChain.Message.new_system!(@system_prompt))

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
    messages = Enum.map(messages, &to_langchain_message/1)

    handler = %{
      on_llm_new_delta: fn _model, %LangChain.MessageDelta{} = data ->
        send(receiver, {:next_message_delta, assistant_message, data})
      end,
      on_message_processed: fn _chain, %LangChain.Message{} = data ->
        completed_message = update_message!(assistant_message, %{content: data.content})

        send(receiver, {:message_processed, completed_message})
      end
    }

    {:ok, _chain} =
      @chain
      |> LLMChain.add_callback(handler)
      |> LLMChain.add_messages(messages)
      |> LLMChain.run()

    assistant_message
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
