defmodule Chatbot.Repo.Migrations.AddSourcesToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:sources, {:array, :string})
    end
  end
end
