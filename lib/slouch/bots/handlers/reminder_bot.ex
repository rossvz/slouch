defmodule Slouch.Bots.Handlers.ReminderBot do
  @behaviour Slouch.Bots.Handler

  require Logger

  alias Slouch.Bots.Responder

  @impl true
  def handle_mention(message, channel, bot) do
    case parse_command(message.body, bot.name) do
      {:remind, delay_ms, human_time, reminder_text} ->
        schedule_reminder(delay_ms, human_time, reminder_text, message, channel, bot)

      :help ->
        show_help(message, channel, bot)
    end
  end

  defp parse_command(body, bot_name) do
    remind_pattern =
      ~r/@#{Regex.escape(bot_name)}\s+remind\s+me\s+in\s+(\d+)\s*(seconds?|s|minutes?|m|hours?|h)\s+to\s+(.+)/i

    case Regex.run(remind_pattern, body) do
      [_, amount_str, unit, text] ->
        amount = String.to_integer(amount_str)
        delay_ms = to_milliseconds(amount, String.downcase(unit))
        human_time = humanize_duration(amount, String.downcase(unit))
        {:remind, delay_ms, human_time, String.trim(text)}

      nil ->
        :help
    end
  end

  defp to_milliseconds(amount, unit) when unit in ["s", "second", "seconds"],
    do: amount * 1_000

  defp to_milliseconds(amount, unit) when unit in ["m", "minute", "minutes"],
    do: amount * 60 * 1_000

  defp to_milliseconds(amount, unit) when unit in ["h", "hour", "hours"],
    do: amount * 60 * 60 * 1_000

  defp humanize_duration(amount, unit) when unit in ["s", "second", "seconds"] do
    "#{amount} second#{if amount == 1, do: "", else: "s"}"
  end

  defp humanize_duration(amount, unit) when unit in ["m", "minute", "minutes"] do
    "#{amount} minute#{if amount == 1, do: "", else: "s"}"
  end

  defp humanize_duration(amount, unit) when unit in ["h", "hour", "hours"] do
    "#{amount} hour#{if amount == 1, do: "", else: "s"}"
  end

  defp schedule_reminder(delay_ms, human_time, reminder_text, message, channel, bot) do
    user_name =
      if Ash.Resource.loaded?(message, :user) && message.user do
        message.user.display_name || message.user.email
      else
        "someone"
      end

    Responder.add_reaction("✅", message, bot)

    Responder.post_reply(
      "Got it! I'll remind you in #{human_time}. ⏰",
      message,
      channel,
      bot
    )

    spawn(fn ->
      Process.sleep(delay_ms)
      Responder.post_message("⏰ Hey @#{user_name}! Reminder: #{reminder_text}", channel, bot)
    end)

    Responder.record_activity(bot)
    :ok
  end

  defp show_help(message, channel, bot) do
    help_text = """
    ⏰ **ReminderBot Help**

    Set a reminder:
    `@#{bot.name} remind me in <amount> <unit> to <text>`

    Supported time units:
    - Seconds: `30 seconds`, `30s`
    - Minutes: `5 minutes`, `5m`
    - Hours: `2 hours`, `2h`

    Examples:
    - `@#{bot.name} remind me in 30 minutes to check the build`
    - `@#{bot.name} remind me in 2h to review the PR`
    - `@#{bot.name} remind me in 10s to grab coffee`
    """

    Responder.post_reply(help_text, message, channel, bot)
    Responder.record_activity(bot)
    :ok
  end
end
