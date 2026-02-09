defmodule Slouch.Bots.Handlers.PollBot do
  @behaviour Slouch.Bots.Handler

  require Logger

  alias Slouch.Bots.Responder

  @number_emoji %{
    1 => "1️⃣",
    2 => "2️⃣",
    3 => "3️⃣",
    4 => "4️⃣",
    5 => "5️⃣",
    6 => "6️⃣",
    7 => "7️⃣",
    8 => "8️⃣",
    9 => "9️⃣"
  }

  @impl true
  def handle_mention(message, channel, bot) do
    case parse_command(message.body, bot.name) do
      {:create_poll, question, options} ->
        create_poll(question, options, channel, bot)

      :help ->
        show_help(message, channel, bot)

      {:error, reason} ->
        Responder.post_reply(reason, message, channel, bot)
        Responder.record_activity(bot)
        :ok
    end
  end

  defp parse_command(body, bot_name) do
    help_pattern = ~r/@#{Regex.escape(bot_name)}\s+help/i

    if Regex.match?(help_pattern, body) do
      :help
    else
      create_pattern = ~r/@#{Regex.escape(bot_name)}\s+create\s+/i

      if Regex.match?(create_pattern, body) do
        parse_poll_args(body, bot_name)
      else
        :help
      end
    end
  end

  defp parse_poll_args(body, bot_name) do
    stripped = Regex.replace(~r/@#{Regex.escape(bot_name)}\s+create\s*/i, body, "")
    parts = Regex.scan(~r/"([^"]+)"/, stripped, capture: :all_but_first) |> List.flatten()

    case parts do
      [question | options] when length(options) >= 2 and length(options) <= 9 ->
        {:create_poll, question, options}

      [_question | options] when length(options) < 2 ->
        {:error, "Polls need at least 2 options. See `@#{bot_name} help` for usage."}

      [_question | options] when length(options) > 9 ->
        {:error, "Polls support a maximum of 9 options."}

      _ ->
        {:error, "Couldn't parse that. Make sure to wrap the question and each option in quotes. See `@#{bot_name} help` for usage."}
    end
  end

  defp create_poll(question, options, channel, bot) do
    options_text =
      options
      |> Enum.with_index(1)
      |> Enum.map(fn {option, idx} ->
        emoji = Map.get(@number_emoji, idx)
        "#{emoji}  #{option}"
      end)
      |> Enum.join("\n")

    poll_message = """
    📊 **Poll: #{question}**

    #{options_text}

    React with the corresponding number to vote!
    """

    Responder.post_message(poll_message, channel, bot)
    Responder.record_activity(bot)
    :ok
  end

  defp show_help(message, channel, bot) do
    help_text = """
    📊 **PollBot Help**

    Create a poll:
    `@#{bot.name} create "Your question?" "Option 1" "Option 2" "Option 3"`

    - Wrap the question and each option in double quotes
    - Supports 2 to 9 options
    - React with number emoji to vote!

    Example:
    `@#{bot.name} create "Best programming language?" "Elixir" "Rust" "Python"`
    """

    Responder.post_reply(help_text, message, channel, bot)
    Responder.record_activity(bot)
    :ok
  end
end
