defmodule Slouch.Bots.Dispatcher do
  use GenServer

  require Logger

  @rate_limit_ms 5_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Phoenix.PubSub.subscribe(Slouch.PubSub, "bot:mentions")
    Phoenix.PubSub.subscribe(Slouch.PubSub, "bot:channel_join")
    Phoenix.PubSub.subscribe(Slouch.PubSub, "bot:all_messages")

    schedule_bots()

    {:ok, state |> Map.put(:rate_limits, %{}) |> Map.put(:welcomed, MapSet.new())}
  end

  @impl true
  def handle_info({:check_mentions, message, channel}, state) do
    Task.start(fn -> process_mentions(message, channel) end)
    {:noreply, state}
  end

  def handle_info({:check_all_messages, message, channel}, state) do
    Task.start(fn -> process_keywords(message, channel) end)
    {:noreply, state}
  end

  def handle_info({:channel_join, user, channel}, state) do
    key = {user.id, channel.id}

    if MapSet.member?(state.welcomed, key) do
      Logger.debug("Dispatcher: already welcomed user #{user.id} in channel #{channel.id}")
      {:noreply, state}
    else
      Task.start(fn -> process_channel_join(user, channel) end)
      {:noreply, %{state | welcomed: MapSet.put(state.welcomed, key)}}
    end
  end

  def handle_info(:run_scheduled, state) do
    Task.start(fn -> process_scheduled() end)
    Process.send_after(self(), :run_scheduled, :timer.minutes(1))
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_bots do
    Process.send_after(self(), :run_scheduled, :timer.seconds(30))
  end

  defp process_mentions(message, channel) do
    bots = load_active_bots()

    for bot <- bots, bot.trigger_type in ["mention", "all_messages"] do
      if mentioned?(message.body, bot.name) do
        handler = String.to_existing_atom(bot.handler_module)

        if rate_limited?(bot, channel) do
          Logger.debug("Bot #{bot.name} rate limited in channel #{channel.id}")
        else
          try do
            handler.handle_mention(message, channel, bot)
            track_rate_limit(bot, channel)
            Slouch.Bots.Responder.record_activity(bot)
          rescue
            e ->
              Logger.error("Bot #{bot.name} failed to handle mention: #{inspect(e)}")
          end
        end
      end
    end
  end

  defp process_keywords(message, channel) do
    bots = load_bots_by_trigger("keyword")

    for bot <- bots do
      keywords = Map.get(bot.config, "keywords", [])
      body_lower = String.downcase(message.body)

      matched = Enum.find(keywords, fn kw -> String.contains?(body_lower, String.downcase(kw)) end)

      if matched && !mentioned?(message.body, bot.name) do
        handler = String.to_existing_atom(bot.handler_module)

        if function_exported?(handler, :handle_keyword, 4) do
          try do
            handler.handle_keyword(message, channel, bot, matched)
            Slouch.Bots.Responder.record_activity(bot)
          rescue
            e ->
              Logger.error("Bot #{bot.name} failed to handle keyword '#{matched}': #{inspect(e)}")
          end
        end
      end
    end
  end

  defp process_channel_join(user, channel) do
    bots = load_bots_by_trigger("channel_join")

    for bot <- bots do
      if bot.user_id != user.id do
        handler = String.to_existing_atom(bot.handler_module)

        if function_exported?(handler, :handle_channel_join, 3) do
          try do
            handler.handle_channel_join(user, channel, bot)
            Slouch.Bots.Responder.record_activity(bot)
          rescue
            e ->
              Logger.error("Bot #{bot.name} failed to handle channel join: #{inspect(e)}")
          end
        end
      end
    end
  end

  defp process_scheduled do
    bots = load_bots_by_trigger("schedule")

    for bot <- bots do
      handler = String.to_existing_atom(bot.handler_module)

      if function_exported?(handler, :handle_schedule, 1) do
        try do
          handler.handle_schedule(bot)
          Slouch.Bots.Responder.record_activity(bot)
        rescue
          e ->
            Logger.error("Bot #{bot.name} failed scheduled run: #{inspect(e)}")
        end
      end
    end
  end

  defp load_active_bots do
    Slouch.Bots.Bot
    |> Ash.Query.for_read(:active, %{})
    |> Ash.read!(authorize?: false)
  end

  defp load_bots_by_trigger(trigger_type) do
    Slouch.Bots.Bot
    |> Ash.Query.for_read(:by_trigger, %{trigger_type: trigger_type})
    |> Ash.read!(authorize?: false)
  end

  defp mentioned?(body, bot_name) do
    String.contains?(String.downcase(body), "@#{String.downcase(bot_name)}")
  end

  # Simple in-memory rate limiting using process dictionary
  defp rate_limited?(bot, channel) do
    key = {bot.id, channel.id}
    last = Process.get({:rate_limit, key})
    last != nil && System.monotonic_time(:millisecond) - last < @rate_limit_ms
  end

  defp track_rate_limit(bot, channel) do
    key = {bot.id, channel.id}
    Process.put({:rate_limit, key}, System.monotonic_time(:millisecond))
  end
end
