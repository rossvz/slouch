defmodule Slouch.Bots.Handler do
  @callback handle_mention(
              message :: Slouch.Chat.Message.t(),
              channel :: Slouch.Chat.Channel.t(),
              bot :: Slouch.Bots.Bot.t()
            ) :: :ok | {:error, term()}
end
