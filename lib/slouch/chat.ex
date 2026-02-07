defmodule Slouch.Chat do
  use Ash.Domain, otp_app: :slouch, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Slouch.Chat.Channel
    resource Slouch.Chat.Message
    resource Slouch.Chat.Membership
    resource Slouch.Chat.Reaction
  end
end
