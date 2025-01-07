defmodule Chatbot.Chat.Message do
  @moduledoc """
  The Message schema.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import BitcrowdEcto.Changeset

  @type t :: %__MODULE__{}

  @message_types [:user, :assistant, :system]

  schema "messages" do
    field :role, Ecto.Enum, values: @message_types
    field :content, :string
    field :sources, {:array, :string}

    timestamps()
  end

  @doc """
  Changeset for creating or updating a Message.
  """
  @spec changeset(map()) :: Ecto.Changeset.t()
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, [:role, :sources])
    |> cast(attrs, [:content], empty_values: [nil])
    # we cannot require the content, as
    # validate_required still considers "" as empty
    |> validate_required([:role])
    |> validate_immutable(:role)
  end
end
