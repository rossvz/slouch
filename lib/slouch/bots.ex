defmodule Slouch.Bots do
  use Ash.Domain, otp_app: :slouch, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Slouch.Bots.Bot
  end
end
