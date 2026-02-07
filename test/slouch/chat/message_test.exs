defmodule Slouch.Chat.MessageTest do
  use Slouch.DataCase, async: true

  import Slouch.TestHelpers

  setup do
    user = create_user()
    channel = create_channel()
    %{user: user, channel: channel}
  end

  describe "create" do
    test "creates a message with body, channel, and user", %{user: user, channel: channel} do
      message = create_message(channel, user, %{body: "Hello world"})

      assert message.body == "Hello world"
      assert message.channel_id == channel.id
      assert message.user_id == user.id
    end

    test "requires body", %{user: user, channel: channel} do
      assert_raise Ash.Error.Invalid, fn ->
        Slouch.Chat.Message
        |> Ash.Changeset.for_create(:create, %{channel_id: channel.id}, actor: user)
        |> Ash.create!()
      end
    end

    test "requires channel_id", %{user: user} do
      assert_raise Ash.Error.Invalid, fn ->
        Slouch.Chat.Message
        |> Ash.Changeset.for_create(:create, %{body: "test"}, actor: user)
        |> Ash.create!()
      end
    end

    test "creates a threaded reply", %{user: user, channel: channel} do
      parent = create_message(channel, user, %{body: "parent"})
      reply = create_message(channel, user, %{body: "reply", parent_message_id: parent.id})

      assert reply.parent_message_id == parent.id
    end
  end

  describe "by_channel" do
    test "returns messages for a channel excluding thread replies", %{
      user: user,
      channel: channel
    } do
      create_message(channel, user, %{body: "top-level"})
      parent = create_message(channel, user, %{body: "parent msg"})
      create_message(channel, user, %{body: "reply", parent_message_id: parent.id})

      messages =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      bodies = Enum.map(messages, & &1.body)
      assert "top-level" in bodies
      assert "parent msg" in bodies
      refute "reply" in bodies
    end

    test "returns messages sorted by inserted_at ascending", %{user: user, channel: channel} do
      create_message(channel, user, %{body: "first"})
      create_message(channel, user, %{body: "second"})

      messages =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert Enum.map(messages, & &1.body) == ["first", "second"]
    end

    test "preloads user, reply_count, and reactions", %{user: user, channel: channel} do
      message = create_message(channel, user, %{body: "preloaded"})
      create_reaction(message, user, "👍")

      [loaded] =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert loaded.user.id == user.id
      assert loaded.reply_count == 0
      assert length(loaded.reactions) == 1
    end

    test "does not return messages from other channels", %{user: user, channel: channel} do
      other_channel = create_channel()
      create_message(channel, user, %{body: "in channel"})
      create_message(other_channel, user, %{body: "in other"})

      messages =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert length(messages) == 1
      assert hd(messages).body == "in channel"
    end
  end

  describe "thread_replies" do
    test "returns replies for a parent message", %{user: user, channel: channel} do
      parent = create_message(channel, user, %{body: "parent"})
      create_message(channel, user, %{body: "reply 1", parent_message_id: parent.id})
      create_message(channel, user, %{body: "reply 2", parent_message_id: parent.id})

      replies =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:thread_replies, %{parent_message_id: parent.id})
        |> Ash.read!()

      assert length(replies) == 2
      assert Enum.map(replies, & &1.body) == ["reply 1", "reply 2"]
    end
  end

  describe "reply_count aggregate" do
    test "counts replies", %{user: user, channel: channel} do
      parent = create_message(channel, user, %{body: "parent"})
      create_message(channel, user, %{body: "r1", parent_message_id: parent.id})
      create_message(channel, user, %{body: "r2", parent_message_id: parent.id})

      parent = Ash.load!(parent, :reply_count)
      assert parent.reply_count == 2
    end
  end

  describe "destroy" do
    test "deletes a message", %{user: user, channel: channel} do
      message = create_message(channel, user)
      Ash.destroy!(message)

      messages =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert messages == []
    end
  end
end
