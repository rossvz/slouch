defmodule Slouch.Accounts.UserTest do
  use Slouch.DataCase, async: true

  import Slouch.TestHelpers

  describe "register_with_password" do
    test "creates a user with valid attributes" do
      user =
        Slouch.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "new@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.create!(authorize?: false)

      assert to_string(user.email) == "new@example.com"
      assert user.hashed_password
    end

    test "requires email" do
      assert_raise Ash.Error.Invalid, fn ->
        Slouch.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.create!(authorize?: false)
      end
    end

    test "enforces unique email" do
      create_user(%{email: "dupe@example.com"})

      assert_raise Ash.Error.Invalid, fn ->
        Slouch.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "dupe@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        })
        |> Ash.create!(authorize?: false)
      end
    end
  end

  describe "update_profile" do
    test "updates display_name, status_emoji, and status_text" do
      user = create_user()

      updated =
        user
        |> Ash.Changeset.for_update(:update_profile, %{
          display_name: "Test User",
          status_emoji: "🎉",
          status_text: "Having fun"
        })
        |> Ash.update!(actor: user)

      assert updated.display_name == "Test User"
      assert updated.status_emoji == "🎉"
      assert updated.status_text == "Having fun"
    end

    test "only the user can update their own profile" do
      user = create_user()
      other_user = create_user()

      assert_raise Ash.Error.Forbidden, fn ->
        user
        |> Ash.Changeset.for_update(:update_profile, %{display_name: "Hacked"})
        |> Ash.update!(actor: other_user)
      end
    end
  end

  describe "read" do
    test "anyone can read users" do
      user = create_user()
      other_user = create_user()

      users = Ash.read!(Slouch.Accounts.User, actor: other_user)
      ids = Enum.map(users, & &1.id)
      assert user.id in ids
    end
  end

  describe "calculations" do
    test "avatar_url is based on email" do
      user = create_user(%{email: "avatar@test.com"})
      user = Ash.load!(user, :avatar_url)

      assert user.avatar_url =~ "avatar@test.com"
      assert user.avatar_url =~ "dicebear"
    end

    test "display_label falls back to email when no display_name" do
      user = create_user(%{email: "label@test.com"})
      user = Ash.load!(user, :display_label)

      assert to_string(user.display_label) == "label@test.com"
    end

    test "display_label uses display_name when set" do
      user = create_user()

      user =
        user
        |> Ash.Changeset.for_update(:update_profile, %{display_name: "Cool Name"})
        |> Ash.update!(actor: user)
        |> Ash.load!(:display_label)

      assert user.display_label == "Cool Name"
    end
  end
end
