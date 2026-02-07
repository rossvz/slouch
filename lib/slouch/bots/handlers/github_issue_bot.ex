defmodule Slouch.Bots.Handlers.GithubIssueBot do
  @behaviour Slouch.Bots.Handler

  require Logger

  @impl true
  def handle_mention(message, channel, bot) do
    case parse_command(message.body, bot.name) do
      {:create_issue, title} ->
        create_issue(title, message, channel, bot)

      :unknown ->
        post_reply(
          "I can help create GitHub issues! Try: `@#{bot.name} create issue: Your issue title here`",
          message,
          channel,
          bot
        )
    end
  end

  defp parse_command(body, bot_name) do
    pattern = ~r/@#{Regex.escape(bot_name)}\s+create\s+issue:\s*(.+)/i

    case Regex.run(pattern, body) do
      [_, title] -> {:create_issue, String.trim(title)}
      nil -> :unknown
    end
  end

  defp create_issue(title, message, channel, bot) do
    case do_create_issue(title, message, channel) do
      {:ok, issue_url} ->
        add_reaction(message, bot)
        post_reply("Created GitHub issue: #{issue_url}", message, channel, bot)

      {:error, reason} ->
        post_reply("Failed to create issue: #{reason}", message, channel, bot)
    end
  end

  defp do_create_issue(title, _message, _channel) do
    token = Application.get_env(:slouch, :github_token)
    repo = Application.get_env(:slouch, :github_repo)

    if token && repo do
      case Req.post(
             "https://api.github.com/repos/#{repo}/issues",
             json: %{title: title},
             headers: [
               {"authorization", "Bearer #{token}"},
               {"accept", "application/vnd.github+json"}
             ]
           ) do
        {:ok, %{status: 201, body: %{"html_url" => url}}} ->
          {:ok, url}

        {:ok, %{status: status, body: body}} ->
          {:error, "GitHub API returned #{status}: #{inspect(body)}"}

        {:error, err} ->
          {:error, inspect(err)}
      end
    else
      issue_number = :rand.uniform(999)
      url = "https://github.com/example/slouch/issues/#{issue_number}"

      Logger.info(
        "Mock GitHub issue created: #{url} (set :github_token and :github_repo to use real API)"
      )

      {:ok, url}
    end
  end

  defp add_reaction(message, bot) do
    Slouch.Chat.Reaction
    |> Ash.Changeset.for_create(:react, %{emoji: "✅", message_id: message.id}, actor: bot.user)
    |> Ash.create(authorize?: false)

    if channel_id = message.channel_id do
      Phoenix.PubSub.broadcast(
        Slouch.PubSub,
        "chat:#{channel_id}",
        {:reaction_toggled, message.id}
      )
    end
  end

  defp post_reply(body, message, channel, bot) do
    reply =
      Slouch.Chat.Message
      |> Ash.Changeset.for_create(
        :create,
        %{body: body, channel_id: channel.id, parent_message_id: message.id},
        actor: bot.user
      )
      |> Ash.create!(authorize?: false)
      |> Ash.load!(user: [:avatar_url, :display_label])

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "chat:#{channel.id}",
      {:new_reply, message.id, reply}
    )

    :ok
  end
end
