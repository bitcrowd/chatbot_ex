defmodule ChatbotWeb.ChatLive do
  use ChatbotWeb, :live_view
  alias Chatbot.Chat
  import ChatbotWeb.CoreComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:messages, Chat.all_messages())
      |> assign(:form, to_form(%{"message" => ""}))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <header>
      <.ui_page_title class="u-fg-brand-1 u-padding-l3-top u-margin-l3-bottom">
        Chatbot
      </.ui_page_title>
    </header>

    <main class="u-grid u-gap-l1">
      <%= for message <- @messages do %>
        <.chat_message role={message.role} content={message.content} />
      <% end %>

      <.simple_form for={@form} phx-submit="send" class="u-justify-self-end u-width-75">
        <.ui_input
          type="textarea"
          form={@form}
          field={:message}
          label="Message"
          hidden_label={true}
          maxlength="5000"
          placeholder="Ask a question"
        />
        <:actions>
          <.ui_button>Send</.ui_button>
        </:actions>
      </.simple_form>
    </main>
    """
  end

  defp chat_message(assigns) do
    justify_self =
      if assigns.role == :user, do: "u-justify-self-end", else: "u-justify-self-start"

    assigns = assign(assigns, :class, "u-max-width-75 u-bg-white " <> justify_self)

    ~H"""
    <.ui_card class={@class}><%= @content %></.ui_card>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("send", %{"message" => message}, socket) do
    messages = socket.assigns.messages
    user_message = Chat.new_user_message(%{role: :user, content: message})

    messages = messages ++ [user_message]

    send(self(), {:stream_assistant_message, messages})

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl Phoenix.LiveView
  def handle_info({:new_assistant_message, messages}, socket) do
    {:ok, assistant_message} = Chat.new_assistant_message(messages)

    messages = messages ++ [assistant_message]
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:stream_assistant_message, messages}, socket) do
    Chat.stream_assistant_message(messages, self())

    messages = messages ++ [%{role: :assistant, content: ""}]

    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:next_message_delta, nil}, socket) do
    {:noreply, socket}
  end

  def handle_info({:next_message_delta, message_delta}, socket) do
    [latest_assistant_message | messages] = Enum.reverse(socket.assigns.messages)

    latest_assistant_message = %{
      latest_assistant_message
      | content: latest_assistant_message.content <> message_delta
    }

    messages = [latest_assistant_message | messages] |> Enum.reverse()

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:message_processed, completed_message}, socket) do
    [latest_assistant_message | messages] = Enum.reverse(socket.assigns.messages)

    latest_assistant_message = %{
      latest_assistant_message
      | content: completed_message
    }

    messages = [latest_assistant_message | messages] |> Enum.reverse()

    {:noreply, assign(socket, :messages, messages)}
  end
end
