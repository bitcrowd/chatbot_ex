defmodule ChatbotWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component
  import BitstylesPhoenix.Component.Flash

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="u-grid u-gap-m">
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="u-flex u-flex-wrap u-justify-end u-gap-s2">
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end

  def flash(assigns) do
    ~H"""
    <%= if @info do %>
      <.ui_flash
        variant={[:full, :positive]}
        aria-live="polite"
        phx-click="lv:clear-flash"
        phx-value-key="info"
      >
        <%= @info %>
      </.ui_flash>
    <% end %>
    <%= if @warning do %>
      <.ui_flash
        variant={[:full, :warning]}
        aria-live="polite"
        phx-click="lv:clear-flash"
        phx-value-key="warning"
      >
        <%= @warning %>
      </.ui_flash>
    <% end %>
    <%= if @error do %>
      <.ui_flash
        variant={[:full, :danger]}
        role="alert"
        phx-click="lv:clear-flash"
        phx-value-key="error"
      >
        <%= @error %>
      </.ui_flash>
    <% end %>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(ChatbotWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ChatbotWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
