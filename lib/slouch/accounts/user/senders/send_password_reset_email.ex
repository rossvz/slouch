defmodule Slouch.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """
  use AshAuthentication.Sender

  require Logger

  @impl true
  def send(user, token, _) do
    Logger.debug("Password reset request for #{user.email}, token: #{token}")
  end
end
