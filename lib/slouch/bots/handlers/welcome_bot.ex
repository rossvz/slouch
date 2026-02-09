defmodule Slouch.Bots.Handlers.WelcomeBot do
  @behaviour Slouch.Bots.Handler

  require Logger

  alias Slouch.Bots.Responder

  @impl true
  def handle_mention(message, channel, bot) do
    case parse_command(message.body, bot.name) do
      {:set_greeting, text} ->
        Logger.info("WelcomeBot: Custom greeting set for ##{channel.name}: #{text}")

        Responder.post_reply(
          "Got it! I'll use that greeting from now on 👍",
          message,
          channel,
          bot
        )

        Responder.record_activity(bot)
        :ok

      :help ->
        help_text = """
        👋 Hi there! I'm #{bot.name}, your friendly neighborhood welcome bot!

        Here's what I can do:
        - I automatically greet people when they join a channel 🎉
        - `@#{bot.name} set greeting: <text>` — Set a custom welcome message
        - `@#{bot.name} help` — Show this help message

        I'm always here to make sure everyone feels welcome! 💛
        """

        Responder.post_reply(help_text, message, channel, bot)
        Responder.record_activity(bot)
        :ok
    end
  end

  @impl true
  def handle_channel_join(user, channel, bot) do
    display_name = user.display_name || user.email

    greeting = """
    👋 Welcome to **##{channel.name}**, #{display_name}! 🎉

    We're so glad you're here! Feel free to introduce yourself and don't hesitate to ask questions. This is a friendly space and we're all here to help! 💛

    Have a wonderful time! ✨
    """

    Responder.post_message(greeting, channel, bot)
    Responder.record_activity(bot)
    :ok
  end

  defp parse_command(body, bot_name) do
    set_pattern = ~r/@#{Regex.escape(bot_name)}\s+set\s+greeting:\s*(.+)/i

    case Regex.run(set_pattern, body) do
      [_, text] -> {:set_greeting, String.trim(text)}
      nil -> :help
    end
  end
end
