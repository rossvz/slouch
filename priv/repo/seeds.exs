alias Slouch.Accounts.User
alias Slouch.Chat.{Channel, Message, Membership, Conversation, ConversationParticipant, DirectMessage}
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
  |> Ash.Changeset.for_create(:create, %{name: "random", topic: "Random stuff and water cooler chat"})
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
for {user, channels} <- [{alice, [general, random, engineering]}, {bob, [general, random, watercooler]}] do
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
  |> Ash.Changeset.for_create(:create, %{body: body, conversation_id: conversation.id}, actor: user)
  |> Ash.create!()

  Process.sleep(10)
end

IO.puts("Created DM conversation between Alice and Bob")

# Create bot user and bot record
github_bot_user =
  User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "github-bot@slouch.local",
    password: "botpassword123456",
    password_confirmation: "botpassword123456",
    display_name: "GithubIssueBot"
  })
  |> Ash.create!(authorize?: false)

github_bot_user
|> Ecto.Changeset.change(%{confirmed_at: now, is_bot: true})
|> Slouch.Repo.update!()

Bot
|> Ash.Changeset.for_create(:create, %{
  name: "GithubIssueBot",
  description: "Creates GitHub issues when mentioned. Usage: @GithubIssueBot create issue: Your title here",
  handler_module: "Elixir.Slouch.Bots.Handlers.GithubIssueBot",
  is_active: true,
  user_id: github_bot_user.id
})
|> Ash.create!(authorize?: false)

IO.puts("Created GithubIssueBot")
IO.puts("Seeding complete!")
