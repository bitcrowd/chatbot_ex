# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Chatbot.Repo.insert!(%Chatbot.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Chatbot.{Chat.Message, Repo}

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
timestamps = %{inserted_at: now, updated_at: now}

messages =
  [
    %{
      role: :user,
      content: "What is the tallest tree in the world?"
    },
    %{
      role: :assistant,
      content: """
      The coniferous Coast redwood (Sequoia sempervirens) is the tallest tree species on earth.
      """
    }
  ]
  |> Enum.map(&Map.merge(&1, timestamps))

Repo.insert_all(Message, messages)
