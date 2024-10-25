defmodule Chatbot.LLMMock do
  import LangChain.Utils.ApiOverride
  alias LangChain.MessageDelta

  def use_mock do
    fake_messages = [
      [MessageDelta.new!(%{role: :assistant, content: nil, status: :incomplete})],
      [MessageDelta.new!(%{content: "Thanks for your question. ", status: :incomplete})],
      [MessageDelta.new!(%{content: "Let me think about that. ", status: :incomplete})],
      [MessageDelta.new!(%{content: "... ", status: :incomplete})],
      [MessageDelta.new!(%{content: "I don't have an answer right now. ", status: :incomplete})],
      [
        MessageDelta.new!(%{
          content: "Please try another question. Maybe I can help with that.",
          status: :complete
        })
      ]
    ]

    set_api_override({:ok, fake_messages, :on_llm_new_delta})
  end
end
