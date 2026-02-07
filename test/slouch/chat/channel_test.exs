defmodule Slouch.Chat.ChannelTest do
  use Slouch.DataCase, async: true

  import Slouch.TestHelpers

  describe "create" do
    test "creates a channel with valid attributes" do
      channel = create_channel(%{name: "general", topic: "General discussion"})

      assert channel.name == "general"
      assert channel.topic == "General discussion"
      assert channel.id
    end

    test "creates a channel without topic" do
      channel = create_channel(%{name: "random"})

      assert channel.name == "random"
      assert channel.topic == nil
    end

    test "requires name" do
      assert_raise Ash.Error.Invalid, fn ->
        Slouch.Chat.Channel
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create!()
      end
    end

    test "enforces unique name" do
      create_channel(%{name: "unique-channel"})

      assert_raise Ash.Error.Invalid, fn ->
        create_channel(%{name: "unique-channel"})
      end
    end
  end

  describe "read" do
    test "lists all channels" do
      create_channel(%{name: "alpha"})
      create_channel(%{name: "beta"})

      channels = Ash.read!(Slouch.Chat.Channel)
      names = Enum.map(channels, & &1.name)

      assert "alpha" in names
      assert "beta" in names
    end
  end

  describe "update" do
    test "updates channel name and topic" do
      channel = create_channel(%{name: "old-name", topic: "old topic"})

      updated =
        channel
        |> Ash.Changeset.for_update(:update, %{name: "new-name", topic: "new topic"})
        |> Ash.update!()

      assert updated.name == "new-name"
      assert updated.topic == "new topic"
    end
  end

  describe "destroy" do
    test "deletes a channel" do
      channel = create_channel(%{name: "to-delete"})
      Ash.destroy!(channel)

      assert Ash.read!(Slouch.Chat.Channel) == []
    end
  end

  describe "relationships" do
    test "has messages" do
      channel = create_channel()
      user = create_user()
      create_message(channel, user, %{body: "hello"})

      channel = Ash.load!(channel, :messages)
      assert length(channel.messages) == 1
    end

    test "has members through memberships" do
      channel = create_channel()
      user = create_user()
      create_membership(channel, user)

      channel = Ash.load!(channel, :members)
      assert length(channel.members) == 1
      assert hd(channel.members).id == user.id
    end
  end
end
