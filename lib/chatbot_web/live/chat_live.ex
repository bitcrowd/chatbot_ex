defmodule ChatbotWeb.ChatLive do
  use ChatbotWeb, :live_view
  import ChatbotWeb.CoreComponents
  import BitcrowdEcto.Random, only: [uuid: 0]
  alias Chatbot.{Chat}
  alias Phoenix.PubSub

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(Chatbot.PubSub, "rag")

    socket =
      socket
      |> stream(:messages, Chat.all_messages())
      |> assign(:currently_streamed_response, nil)
      |> assign(:current_activity, nil)
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
          sources={message.sources}
        />
      </div>

      <div class="u-grid u-gap-l1 u-margin-l1-top">
        <.ui_card :if={@current_activity}>
          <span class="loader"></span>
          <%= @current_activity %>
        </.ui_card>
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

    markdown_html =
      String.trim(assigns.content)
      |> Earmark.as_html!()
      |> Phoenix.HTML.raw()

    assigns =
      assigns
      |> assign(:class, "u-max-width-75 u-bg-white " <> justify_self)
      |> assign(:markdown, markdown_html)

    ~H"""
    <.ui_card id={@id} class={@class}>
      <%= @markdown %>

      <details :if={@sources}>
        <summary>Sources</summary>
        <ol>
          <li :for={source <- @sources}>
            <%= source %>
          </li>
        </ol>
      </details>
    </.ui_card>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("send", %{"message" => %{"content" => content}}, socket) do
    messages = Chat.all_messages()

    pid = self()

    with {:ok, user_message} <- Chat.create_message(%{role: :user, content: content}),
         {:ok, assistant_message} <- Chat.create_message(%{role: :assistant, content: ""}) do
      {:noreply,
       socket
       |> assign(:form, build_form())
       |> stream(:messages, [user_message, assistant_message])
       |> start_async(:rag, fn ->
         {:ok, augmented_user_message, augmentation} = augment_user_message(user_message)

         assistant_message =
           Chat.update_message!(assistant_message, %{sources: augmentation.context_sources})

         Chat.stream_assistant_message(
           pid,
           messages ++ [augmented_user_message],
           assistant_message
         )
       end)}
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

  def handle_info({:next_message_delta, message, %{status: :incomplete} = message_delta}, socket) do
    currently_streamed_response = socket.assigns.currently_streamed_response

    merged_message_deltas =
      LangChain.MessageDelta.merge_delta(currently_streamed_response, message_delta)

    {:noreply,
     socket
     |> stream_insert(:messages, %{message | content: merged_message_deltas.content})
     |> assign(:currently_streamed_response, merged_message_deltas)}
  end

  def handle_info({:message_processed, completed_message}, socket) do
    {:noreply, stream_insert(socket, :messages, completed_message)}
  end

  def handle_info({:generate_embedding, :start}, socket) do
    {:noreply, assign(socket, current_activity: "looking up information")}
  end

  def handle_info({:retrieve, :stop}, socket) do
    {:noreply, assign(socket, current_activity: "generating response")}
  end

  def handle_info({_key, :exception}, socket) do
    {:noreply, assign(socket, current_activity: "an error occurred :(")}
  end

  def handle_info({_key, _event}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:rag, _no, socket) do
    {:noreply, assign(socket, current_activity: nil)}
  end

  defp build_form do
    %{role: :user, content: ""}
    |> Chat.Message.changeset()
    # we need to give the form an ID, so that
    # PhoenixLiveView knows that this is a new form
    # for a new message and clears the input
    |> to_form(id: uuid())
  end

  defp augment_user_message(user_message) do
    %{role: :user, content: query} = user_message

    rag_generation = Chatbot.Rag.build_generation(query)

    {:ok, %{user_message | content: rag_generation.prompt}, rag_generation}
  end
end
