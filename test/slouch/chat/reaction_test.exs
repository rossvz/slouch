defmodule Slouch.Chat.ReactionTest do
  use Slouch.DataCase, async: true

  import Slouch.TestHelpers

  setup do
    user = create_user()
    channel = create_channel()
    message = create_message(channel, user)
    %{user: user, channel: channel, message: message}
  end

  describe "react" do
    test "creates a reaction", %{user: user, message: message} do
      reaction = create_reaction(message, user, "👍")

      assert reaction.emoji == "👍"
      assert reaction.message_id == message.id
      assert reaction.user_id == user.id
    end

    test "enforces unique reaction per user per message per emoji", %{user: user, message: message} do
      create_reaction(message, user, "👍")

      assert_raise Ash.Error.Invalid, fn ->
        create_reaction(message, user, "👍")
      end
    end

    test "allows same user to react with different emojis", %{user: user, message: message} do
      create_reaction(message, user, "👍")
      r2 = create_reaction(message, user, "😂")

      assert r2.emoji == "😂"
    end

    test "allows different users to react with same emoji", %{message: message} do
      user2 = create_user()
      user3 = create_user()

      create_reaction(message, user2, "🎉")
      create_reaction(message, user3, "🎉")

      reactions =
        Slouch.Chat.Reaction
        |> Ash.Query.for_read(:by_message, %{message_id: message.id})
        |> Ash.read!()

      thumbs = Enum.filter(reactions, &(&1.emoji == "🎉"))
      assert length(thumbs) == 2
    end
  end

  describe "by_message" do
    test "returns reactions for a message", %{user: user, message: message} do
      create_reaction(message, user, "👍")
      create_reaction(message, user, "😂")

      reactions =
        Slouch.Chat.Reaction
        |> Ash.Query.for_read(:by_message, %{message_id: message.id})
        |> Ash.read!()

      assert length(reactions) == 2
      emojis = Enum.map(reactions, & &1.emoji)
      assert "👍" in emojis
      assert "😂" in emojis
    end

    test "does not return reactions from other messages", %{user: user, channel: channel} do
      other_message = create_message(channel, user, %{body: "other"})
      create_reaction(other_message, user, "🚀")

      reactions =
        Slouch.Chat.Reaction
        |> Ash.Query.for_read(:by_message, %{message_id: other_message.id})
        |> Ash.read!()

      assert length(reactions) == 1
      assert hd(reactions).emoji == "🚀"
    end
  end

  describe "destroy" do
    test "removes a reaction", %{user: user, message: message} do
      reaction = create_reaction(message, user, "👍")
      Ash.destroy!(reaction)

      reactions =
        Slouch.Chat.Reaction
        |> Ash.Query.for_read(:by_message, %{message_id: message.id})
        |> Ash.read!()

      assert reactions == []
    end
  end
end
