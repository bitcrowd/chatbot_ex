defmodule Chatbot.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @message_types [:user, :assistant, :system]

  schema "messages" do
    field :role, Ecto.Enum, values: @message_types
    field :content, :string

    timestamps()
  end

  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, [:role, :content])
    |> validate_required([:role, :content])
  end
end
