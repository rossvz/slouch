defmodule Slouch.TestHelpers do
  def create_user(attrs \\ %{}) do
    email = Map.get(attrs, :email, "user-#{System.unique_integer([:positive])}@example.com")

    user =
      Slouch.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)

    user
    |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
    |> Slouch.Repo.update!()
  end

  def create_channel(attrs \\ %{}) do
    name = Map.get(attrs, :name, "channel-#{System.unique_integer([:positive])}")
    topic = Map.get(attrs, :topic)

    Slouch.Chat.Channel
    |> Ash.Changeset.for_create(:create, %{name: name, topic: topic})
    |> Ash.create!(authorize?: false)
  end

  def create_message(channel, user, attrs \\ %{}) do
    body = Map.get(attrs, :body, "test message #{System.unique_integer([:positive])}")
    parent_message_id = Map.get(attrs, :parent_message_id)

    params = %{body: body, channel_id: channel.id}
    params = if parent_message_id, do: Map.put(params, :parent_message_id, parent_message_id), else: params

    Slouch.Chat.Message
    |> Ash.Changeset.for_create(:create, params, actor: user)
    |> Ash.create!(authorize?: false)
  end

  def create_membership(channel, user) do
    Slouch.Chat.Membership
    |> Ash.Changeset.for_create(:join, %{channel_id: channel.id}, actor: user)
    |> Ash.create!(authorize?: false)
  end

  def create_reaction(message, user, emoji \\ "👍") do
    Slouch.Chat.Reaction
    |> Ash.Changeset.for_create(:react, %{emoji: emoji, message_id: message.id}, actor: user)
    |> Ash.create!(authorize?: false)
  end
end
