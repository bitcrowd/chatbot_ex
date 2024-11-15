defmodule ChatbotWeb.ChatLive do
  use ChatbotWeb, :live_view
  import ChatbotWeb.CoreComponents
  import BitcrowdEcto.Random, only: [uuid: 0]
  alias Chatbot.Chat

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream(:messages, Chat.all_messages())
      |> assign(:currently_streamed_response, nil)
      |> assign(:form, build_form())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <header>
      <.ui_page_title class="u-fg-brand-1 u-margin-l3-bottom">
        Chatbot
        <:action>
          <.ui_button phx-click="clear-all" data-confirm="Are you sure?">
            Clear all
          </.ui_button>
        </:action>
      </.ui_page_title>
    </header>

    <main>
      <div id="messages" phx-update="stream" class="u-grid u-gap-l1">
        <.chat_message
          :for={{dom_id, message} <- @streams.messages}
          id={dom_id}
          role={message.role}
          content={message.content}
        />
      </div>

      <div class="u-grid u-gap-l1 u-margin-l1-top">
        <.simple_form for={@form} phx-submit="send" class="u-justify-self-end u-width-75">
          <.ui_input
            type="textarea"
            form={@form}
            field={:content}
            label="Message"
            hidden_label={true}
            maxlength="5000"
            placeholder="Ask a question"
          />
          <:actions>
            <.ui_button type="submit">Send</.ui_button>
          </:actions>
        </.simple_form>
      </div>
    </main>
    """
  end

  defp chat_message(assigns) do
    justify_self =
      if assigns.role == :user, do: "u-justify-self-end", else: "u-justify-self-start"

    assigns = assign(assigns, :class, "u-max-width-75 u-bg-white " <> justify_self)

    ~H"""
    <.ui_card id={@id} class={@class}><%= @content %></.ui_card>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("send", %{"message" => %{"content" => content}}, socket) do
    with {:ok, user_message} <- Chat.create_message(%{role: :user, content: content}),
         assistant_message <- Chat.stream_assistant_message(self()) do
      {:noreply,
       socket
       |> assign(:form, build_form())
       |> stream(:messages, [user_message, assistant_message])}
    end
  end

  def handle_event("clear-all", _params, socket) do
    :ok = Chat.delete_all_messages()

    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl Phoenix.LiveView
  def handle_info({:new_assistant_message, messages}, socket) do
    {:ok, assistant_message} = Chat.request_assistant_message(messages)

    {:noreply, stream_insert(socket, :messages, assistant_message)}
  end

  def handle_info({:next_message_delta, _id, %{status: :complete}}, socket) do
    {:noreply, assign(socket, :currently_streamed_response, nil)}
  end

  def handle_info({:next_message_delta, id, %{status: :incomplete} = message_delta}, socket) do
    currently_streamed_response = socket.assigns.currently_streamed_response

    merged_message_deltas =
      LangChain.MessageDelta.merge_delta(currently_streamed_response, message_delta)

    {:noreply,
     socket
     |> stream_insert(:messages, %{
       id: id,
       role: :assistant,
       content: merged_message_deltas.content
     })
     |> assign(:currently_streamed_response, merged_message_deltas)}
  end

  def handle_info({:message_processed, completed_message}, socket) do
    {:noreply, stream_insert(socket, :messages, completed_message)}
  end

  defp build_form do
    %{role: :user, content: ""}
    |> Chat.Message.changeset()
    # we need to give the form an ID, so that
    # PhoenixLiveView knows that this is a new form
    # for a new message and clears the input
    |> to_form(id: uuid())
  end
end
