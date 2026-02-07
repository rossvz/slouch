defmodule Slouch.Bots.Dispatcher do
  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Phoenix.PubSub.subscribe(Slouch.PubSub, "bot:mentions")
    {:ok, state}
  end

  @impl true
  def handle_info({:check_mentions, message, channel}, state) do
    Task.start(fn -> process_mentions(message, channel) end)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp process_mentions(message, channel) do
    bots =
      Slouch.Bots.Bot
      |> Ash.Query.for_read(:active, %{})
      |> Ash.read!(authorize?: false)

    for bot <- bots do
      if mentioned?(message.body, bot.name) do
        handler = String.to_existing_atom(bot.handler_module)

        try do
          handler.handle_mention(message, channel, bot)
        rescue
          e ->
            Logger.error("Bot #{bot.name} failed to handle mention: #{inspect(e)}")
        end
      end
    end
  end

  defp mentioned?(body, bot_name) do
    String.contains?(String.downcase(body), "@#{String.downcase(bot_name)}")
  end
end
