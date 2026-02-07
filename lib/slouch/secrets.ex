defmodule Slouch.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Slouch.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:slouch, :token_signing_secret)
  end
end
