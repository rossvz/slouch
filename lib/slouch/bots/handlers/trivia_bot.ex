defmodule Slouch.Bots.Handlers.TriviaBot do
  @behaviour Slouch.Bots.Handler

  require Logger

  alias Slouch.Bots.Responder

  @questions [
    {"What planet is known as the Red Planet?", "mars"},
    {"What is the chemical symbol for gold?", "au"},
    {"Who painted the Mona Lisa?", "leonardo da vinci"},
    {"What year did the Berlin Wall fall?", "1989"},
    {"What is the largest ocean on Earth?", "pacific"},
    {"What programming language was created by Guido van Rossum?", "python"},
    {"What is the smallest country in the world?", "vatican city"},
    {"What element has the atomic number 1?", "hydrogen"},
    {"Who wrote '1984'?", "george orwell"},
    {"What is the speed of light in km/s (approximately)?", "300000"},
    {"What company created the iPhone?", "apple"},
    {"What is the capital of Japan?", "tokyo"},
    {"How many bits are in a byte?", "8"},
    {"Who discovered penicillin?", "alexander fleming"},
    {"What is the tallest mountain in the world?", "everest"},
    {"What year was the first Moon landing?", "1969"},
    {"What gas do plants absorb from the atmosphere?", "carbon dioxide"},
    {"What is the name of the protocol that powers the World Wide Web?", "http"},
    {"In what decade was Elixir first released?", "2010"},
    {"What is the hardest natural substance on Earth?", "diamond"},
    {"Who played Iron Man in the MCU?", "robert downey"},
    {"What is the largest mammal in the world?", "blue whale"},
    {"What does CPU stand for?", "central processing unit"},
    {"What is the most spoken language in the world?", "mandarin"}
  ]

  @impl true
  def handle_mention(message, channel, bot) do
    ensure_ets_table()

    case parse_command(message.body, bot.name) do
      {:answer, text} ->
        check_answer(text, message, channel, bot)

      :score ->
        show_score(message, channel, bot)

      :trivia ->
        ask_question(message, channel, bot)
    end
  end

  defp parse_command(body, bot_name) do
    answer_pattern = ~r/@#{Regex.escape(bot_name)}\s+answer\s+(.+)/i
    score_pattern = ~r/@#{Regex.escape(bot_name)}\s+score/i

    cond do
      match = Regex.run(answer_pattern, body) ->
        {:answer, String.trim(Enum.at(match, 1))}

      Regex.match?(score_pattern, body) ->
        :score

      true ->
        :trivia
    end
  end

  defp ask_question(message, channel, bot) do
    {question, _answer} = Enum.random(@questions)
    user_id = message.user_id

    :ets.insert(:trivia_scores, {{user_id, :current_question}, question})

    Responder.post_reply(
      "🧠 **Trivia Time!**\n\n#{question}\n\nReply with `@#{bot.name} answer <your answer>`",
      message,
      channel,
      bot
    )

    Responder.record_activity(bot)
    :ok
  end

  defp check_answer(text, message, channel, bot) do
    user_id = message.user_id

    case :ets.lookup(:trivia_scores, {user_id, :current_question}) do
      [{{^user_id, :current_question}, current_question}] ->
        {_q, correct_answer} =
          Enum.find(@questions, fn {q, _a} -> q == current_question end)

        if String.contains?(String.downcase(text), String.downcase(correct_answer)) do
          Responder.add_reaction("✅", message, bot)
          increment_score(user_id)
          :ets.delete(:trivia_scores, {user_id, :current_question})
          score = get_score(user_id)

          Responder.post_reply(
            "🎉 **Correct!** The answer is **#{correct_answer}**. You're on a roll! (Score: #{score})",
            message,
            channel,
            bot
          )
        else
          Responder.add_reaction("❌", message, bot)

          Responder.post_reply(
            "Not quite! The correct answer was **#{correct_answer}**. Better luck next time! 💪",
            message,
            channel,
            bot
          )
        end

        Responder.record_activity(bot)
        :ok

      [] ->
        Responder.post_reply(
          "You don't have an active question! Say `@#{bot.name} trivia` to get one.",
          message,
          channel,
          bot
        )

        Responder.record_activity(bot)
        :ok
    end
  end

  defp show_score(message, channel, bot) do
    score = get_score(message.user_id)

    Responder.post_reply(
      "📊 Your trivia score: **#{score}** correct answers!",
      message,
      channel,
      bot
    )

    Responder.record_activity(bot)
    :ok
  end

  defp ensure_ets_table do
    try do
      :ets.new(:trivia_scores, [:set, :public, :named_table])
    rescue
      ArgumentError -> :ok
    end
  end

  defp increment_score(user_id) do
    current = get_score(user_id)
    :ets.insert(:trivia_scores, {{user_id, :score}, current + 1})
  end

  defp get_score(user_id) do
    case :ets.lookup(:trivia_scores, {user_id, :score}) do
      [{{^user_id, :score}, score}] -> score
      [] -> 0
    end
  end
end
