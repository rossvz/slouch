defmodule Slouch.Bots.DispatcherTest do
  use Slouch.DataCase, async: false

  import Slouch.TestHelpers

  alias Slouch.Bots.Dispatcher

  defp create_bot_with_user(attrs \\ %{}) do
    bot_user =
      create_user(%{email: "test-bot-#{System.unique_integer([:positive])}@slouch.bot"})
      |> Ecto.Changeset.change(%{is_bot: true})
      |> Slouch.Repo.update!()

    Slouch.Bots.Bot
    |> Ash.Changeset.for_create(:create, %{
      name: Map.get(attrs, :name, "TestBot-#{System.unique_integer([:positive])}"),
      handler_module: Map.get(attrs, :handler_module, "Elixir.Slouch.Bots.Handlers.WelcomeBot"),
      trigger_type: Map.get(attrs, :trigger_type, "channel_join"),
      is_active: true,
      user_id: bot_user.id
    })
    |> Ash.create!(authorize?: false)
    |> Ash.load!(:user)
  end

  describe "channel_join deduplication" do
    test "only processes channel_join once per user/channel pair" do
      _bot = create_bot_with_user()
      user = create_user()
      channel = create_channel()

      Phoenix.PubSub.subscribe(Slouch.PubSub, "chat:#{channel.id}")

      send(Dispatcher, {:channel_join, user, channel})
      send(Dispatcher, {:channel_join, user, channel})
      send(Dispatcher, {:channel_join, user, channel})

      # Wait for async tasks to complete
      Process.sleep(500)

      messages = collect_messages()
      welcome_messages = Enum.filter(messages, &match?({:new_message, _}, &1))

      assert length(welcome_messages) == 1
    end

    test "welcomes same user in different channels separately" do
      _bot = create_bot_with_user()
      user = create_user()
      channel1 = create_channel(%{name: "ch1"})
      channel2 = create_channel(%{name: "ch2"})

      Phoenix.PubSub.subscribe(Slouch.PubSub, "chat:#{channel1.id}")
      Phoenix.PubSub.subscribe(Slouch.PubSub, "chat:#{channel2.id}")

      send(Dispatcher, {:channel_join, user, channel1})
      send(Dispatcher, {:channel_join, user, channel2})

      Process.sleep(500)

      messages = collect_messages()
      welcome_messages = Enum.filter(messages, &match?({:new_message, _}, &1))

      assert length(welcome_messages) == 2
    end

    test "welcomes different users in the same channel separately" do
      _bot = create_bot_with_user()
      user1 = create_user()
      user2 = create_user()
      channel = create_channel()

      Phoenix.PubSub.subscribe(Slouch.PubSub, "chat:#{channel.id}")

      send(Dispatcher, {:channel_join, user1, channel})
      send(Dispatcher, {:channel_join, user2, channel})

      Process.sleep(500)

      messages = collect_messages()
      welcome_messages = Enum.filter(messages, &match?({:new_message, _}, &1))

      assert length(welcome_messages) == 2
    end
  end

  defp collect_messages do
    collect_messages([])
  end

  defp collect_messages(acc) do
    receive do
      msg -> collect_messages([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
