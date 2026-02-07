defmodule Slouch.Chat.MembershipTest do
  use Slouch.DataCase, async: true

  import Slouch.TestHelpers

  describe "join" do
    test "creates a membership" do
      channel = create_channel()
      user = create_user()

      membership = create_membership(channel, user)

      assert membership.channel_id == channel.id
      assert membership.user_id == user.id
    end

    test "enforces unique membership per user per channel" do
      channel = create_channel()
      user = create_user()

      create_membership(channel, user)

      assert_raise Ash.Error.Invalid, fn ->
        create_membership(channel, user)
      end
    end

    test "allows same user in different channels" do
      channel1 = create_channel(%{name: "ch1"})
      channel2 = create_channel(%{name: "ch2"})
      user = create_user()

      m1 = create_membership(channel1, user)
      m2 = create_membership(channel2, user)

      assert m1.channel_id == channel1.id
      assert m2.channel_id == channel2.id
    end

    test "allows different users in same channel" do
      channel = create_channel()
      user1 = create_user()
      user2 = create_user()

      create_membership(channel, user1)
      create_membership(channel, user2)

      memberships = Ash.read!(Slouch.Chat.Membership)
      assert length(memberships) == 2
    end
  end

  describe "destroy" do
    test "removes a membership" do
      channel = create_channel()
      user = create_user()
      membership = create_membership(channel, user)

      Ash.destroy!(membership)

      assert Ash.read!(Slouch.Chat.Membership) == []
    end
  end
end
