defmodule Slouch.Bots.HandlerRegistry do
  def available_handlers do
    [
      %{
        module: "Elixir.Slouch.Bots.Handlers.GithubIssueBot",
        name: "GitHub Issue Bot",
        description: "Creates GitHub issues when mentioned. Usage: @BotName create issue: Title",
        trigger_type: "mention",
        avatar: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=github-bot"
      },
      %{
        module: "Elixir.Slouch.Bots.Handlers.WelcomeBot",
        name: "Welcome Bot",
        description: "Greets new members when they join a channel with a friendly welcome message.",
        trigger_type: "channel_join",
        avatar: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=welcome-bot"
      },
      %{
        module: "Elixir.Slouch.Bots.Handlers.TriviaBot",
        name: "Trivia Bot",
        description: "Runs trivia games in channels. Mention to get a question, track scores!",
        trigger_type: "mention",
        avatar: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=trivia-bot"
      },
      %{
        module: "Elixir.Slouch.Bots.Handlers.PollBot",
        name: "Poll Bot",
        description: "Creates emoji-reaction polls. Usage: @BotName create \"Question\" \"Opt1\" \"Opt2\"",
        trigger_type: "mention",
        avatar: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=poll-bot"
      },
      %{
        module: "Elixir.Slouch.Bots.Handlers.ReminderBot",
        name: "Reminder Bot",
        description: "Sets reminders. Usage: @BotName remind me in 30 minutes to do something",
        trigger_type: "mention",
        avatar: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=reminder-bot"
      },
      %{
        module: "Elixir.Slouch.Bots.Handlers.DadJokeBot",
        name: "Dad Joke Bot",
        description:
          "Tells dad jokes on mention. Also has a chance to respond to keywords like 'funny' or 'lol'.",
        trigger_type: "mention",
        avatar: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=dad-joke-bot"
      }
    ]
  end
end
