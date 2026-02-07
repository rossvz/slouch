defmodule Slouch.Accounts do
  use Ash.Domain, otp_app: :slouch, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Slouch.Accounts.Token
    resource Slouch.Accounts.User
  end
end
