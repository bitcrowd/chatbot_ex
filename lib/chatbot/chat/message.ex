defmodule Chatbot.Chat.Message do
  @moduledoc """
  The Message schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @message_types [:user, :assistant, :system]

  schema "messages" do
    field :role, Ecto.Enum, values: @message_types
    field :content, :string

    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, [:role, :content])
    |> validate_required([:role, :content])
  end
end
