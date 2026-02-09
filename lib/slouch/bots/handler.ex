defmodule Slouch.Bots.Handler do
  @callback handle_mention(
              message :: Slouch.Chat.Message.t(),
              channel :: Slouch.Chat.Channel.t(),
              bot :: Slouch.Bots.Bot.t()
            ) :: :ok | {:error, term()}

  @callback handle_channel_join(
              user :: Slouch.Accounts.User.t(),
              channel :: Slouch.Chat.Channel.t(),
              bot :: Slouch.Bots.Bot.t()
            ) :: :ok | {:error, term()}

  @callback handle_schedule(
              bot :: Slouch.Bots.Bot.t()
            ) :: :ok | {:error, term()}

  @callback handle_keyword(
              message :: Slouch.Chat.Message.t(),
              channel :: Slouch.Chat.Channel.t(),
              bot :: Slouch.Bots.Bot.t(),
              matched_keyword :: String.t()
            ) :: :ok | {:error, term()}

  @optional_callbacks handle_channel_join: 3, handle_schedule: 1, handle_keyword: 4
end
