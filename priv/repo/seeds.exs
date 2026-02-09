alias Slouch.Accounts.User

alias Slouch.Chat.{
  Channel,
  Message,
  Membership,
  Conversation,
  ConversationParticipant,
  DirectMessage
}

alias Slouch.Bots.Bot

IO.puts("Seeding database...")

# Create users using the password registration strategy
alice =
  User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "alice@example.com",
    password: "password123456",
    password_confirmation: "password123456",
    display_name: "Alice"
  })
  |> Ash.create!(authorize?: false)

bob =
  User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "bob@example.com",
    password: "password123456",
    password_confirmation: "password123456",
    display_name: "Bob"
  })
  |> Ash.create!(authorize?: false)

# Confirm users (bypass email confirmation for seed data)
now = DateTime.utc_now()

for user <- [alice, bob] do
  user
  |> Ecto.Changeset.change(%{confirmed_at: now})
  |> Slouch.Repo.update!()
end

IO.puts("Created users: alice@example.com, bob@example.com (password: password123456)")

# Create channels
general =
  Channel
  |> Ash.Changeset.for_create(:create, %{name: "general", topic: "General discussion"})
  |> Ash.create!()

random =
  Channel
  |> Ash.Changeset.for_create(:create, %{
    name: "random",
    topic: "Random stuff and water cooler chat"
  })
  |> Ash.create!()

engineering =
  Channel
  |> Ash.Changeset.for_create(:create, %{name: "engineering", topic: "Engineering discussions"})
  |> Ash.create!()

watercooler =
  Channel
  |> Ash.Changeset.for_create(:create, %{name: "watercooler", topic: "Off-topic conversations"})
  |> Ash.create!()

IO.puts("Created channels: #general, #random, #engineering, #watercooler")

# Create memberships
for {user, channels} <- [
      {alice, [general, random, engineering]},
      {bob, [general, random, watercooler]}
    ] do
  for channel <- channels do
    Membership
    |> Ash.Changeset.for_create(:join, %{channel_id: channel.id}, actor: user)
    |> Ash.create!()
  end
end

IO.puts("Created memberships")

# Create sample messages in #general
for {user, body} <- [
      {alice, "Hey everyone! Welcome to Slouch!"},
      {bob, "Thanks Alice! Excited to be here."},
      {alice, "Let's build something awesome together."},
      {bob, "Couldn't agree more!"}
    ] do
  Message
  |> Ash.Changeset.for_create(:create, %{body: body, channel_id: general.id}, actor: user)
  |> Ash.create!()

  Process.sleep(10)
end

# Create sample messages in #random
for {user, body} <- [
      {bob, "Anyone seen any good movies lately?"},
      {alice, "Just watched Inception again. Still holds up!"}
    ] do
  Message
  |> Ash.Changeset.for_create(:create, %{body: body, channel_id: random.id}, actor: user)
  |> Ash.create!()

  Process.sleep(10)
end

IO.puts("Created sample messages")

# Create a DM conversation between Alice and Bob
conversation =
  Conversation
  |> Ash.Changeset.for_create(:create, %{})
  |> Ash.create!()

for user <- [alice, bob] do
  ConversationParticipant
  |> Ash.Changeset.for_create(:create, %{conversation_id: conversation.id, user_id: user.id})
  |> Ash.create!()
end

for {user, body} <- [
      {alice, "Hey Bob, want to grab lunch?"},
      {bob, "Sure! How about noon?"},
      {alice, "Perfect, see you then!"}
    ] do
  DirectMessage
  |> Ash.Changeset.for_create(:create, %{body: body, conversation_id: conversation.id},
    actor: user
  )
  |> Ash.create!()

  Process.sleep(10)
end

IO.puts("Created DM conversation between Alice and Bob")

# ── Bot Users & Bots ──

defmodule SeedHelpers do
  def create_bot_user(email, display_name) do
    user =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "botpassword123456",
        password_confirmation: "botpassword123456",
        display_name: display_name
      })
      |> Ash.create!(authorize?: false)

    user
    |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now(), is_bot: true})
    |> Slouch.Repo.update!()
  end
end

bots_config = [
  %{
    email: "github-bot@slouch.bot",
    display_name: "GithubIssueBot",
    name: "GithubIssueBot",
    description: "Creates GitHub issues when mentioned. Usage: @GithubIssueBot create issue: Your title here",
    handler_module: "Elixir.Slouch.Bots.Handlers.GithubIssueBot",
    trigger_type: "mention",
    response_style: "thread",
    avatar_url: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=github-bot",
    config: %{}
  },
  %{
    email: "welcome-bot@slouch.bot",
    display_name: "WelcomeBot",
    name: "WelcomeBot",
    description: "Greets new members when they join a channel with a friendly welcome message.",
    handler_module: "Elixir.Slouch.Bots.Handlers.WelcomeBot",
    trigger_type: "channel_join",
    response_style: "reply",
    avatar_url: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=welcome-bot",
    config: %{}
  },
  %{
    email: "trivia-bot@slouch.bot",
    display_name: "TriviaBot",
    name: "TriviaBot",
    description: "Runs trivia games in channels. Mention to get a question, track scores!",
    handler_module: "Elixir.Slouch.Bots.Handlers.TriviaBot",
    trigger_type: "mention",
    response_style: "thread",
    avatar_url: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=trivia-bot",
    config: %{}
  },
  %{
    email: "poll-bot@slouch.bot",
    display_name: "PollBot",
    name: "PollBot",
    description: "Creates emoji-reaction polls. Usage: @PollBot create \"Question\" \"Opt1\" \"Opt2\"",
    handler_module: "Elixir.Slouch.Bots.Handlers.PollBot",
    trigger_type: "mention",
    response_style: "reply",
    avatar_url: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=poll-bot",
    config: %{}
  },
  %{
    email: "reminder-bot@slouch.bot",
    display_name: "ReminderBot",
    name: "ReminderBot",
    description: "Sets reminders. Usage: @ReminderBot remind me in 30 minutes to check the build",
    handler_module: "Elixir.Slouch.Bots.Handlers.ReminderBot",
    trigger_type: "mention",
    response_style: "thread",
    avatar_url: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=reminder-bot",
    config: %{}
  },
  %{
    email: "dadjoke-bot@slouch.bot",
    display_name: "DadJokeBot",
    name: "DadJokeBot",
    description: "Tells dad jokes on mention. Has a chance to respond to keywords like 'funny' or 'lol'.",
    handler_module: "Elixir.Slouch.Bots.Handlers.DadJokeBot",
    trigger_type: "mention",
    response_style: "thread",
    avatar_url: "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=dad-joke-bot",
    config: %{"keywords" => ["joke", "funny", "laugh", "lol"]}
  }
]

for bot_config <- bots_config do
  bot_user = SeedHelpers.create_bot_user(bot_config.email, bot_config.display_name)

  Bot
  |> Ash.Changeset.for_create(:create, %{
    name: bot_config.name,
    description: bot_config.description,
    handler_module: bot_config.handler_module,
    is_active: true,
    trigger_type: bot_config.trigger_type,
    response_style: bot_config.response_style,
    avatar_url: bot_config.avatar_url,
    config: bot_config.config,
    user_id: bot_user.id
  })
  |> Ash.create!(authorize?: false)

  IO.puts("Created bot: #{bot_config.name}")
end

IO.puts("Seeding complete!")
