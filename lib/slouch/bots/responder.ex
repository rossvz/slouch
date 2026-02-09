defmodule Slouch.Bots.Responder do
  @moduledoc false

  def post_message(body, channel, bot) do
    message =
      Slouch.Chat.Message
      |> Ash.Changeset.for_create(
        :create,
        %{body: body, channel_id: channel.id},
        actor: bot.user
      )
      |> Ash.create!(authorize?: false)
      |> Ash.load!(user: [:avatar_url, :display_label])

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "chat:#{channel.id}",
      {:new_message, message}
    )

    message
  end

  def post_reply(body, parent_message, channel, bot) do
    reply =
      Slouch.Chat.Message
      |> Ash.Changeset.for_create(
        :create,
        %{body: body, channel_id: channel.id, parent_message_id: parent_message.id},
        actor: bot.user
      )
      |> Ash.create!(authorize?: false)
      |> Ash.load!(user: [:avatar_url, :display_label])

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "chat:#{channel.id}",
      {:new_reply, parent_message.id, reply}
    )

    reply
  end

  def add_reaction(emoji, message, bot) do
    Slouch.Chat.Reaction
    |> Ash.Changeset.for_create(:react, %{emoji: emoji, message_id: message.id}, actor: bot.user)
    |> Ash.create(authorize?: false)

    if channel_id = message.channel_id do
      Phoenix.PubSub.broadcast(
        Slouch.PubSub,
        "chat:#{channel_id}",
        {:reaction_toggled, message.id}
      )
    end

    :ok
  end

  def record_activity(bot) do
    bot
    |> Ash.Changeset.for_update(:record_activity, %{})
    |> Ash.update(authorize?: false)
  end
end
