defmodule Slouch.Accounts.User.Senders.SendConfirmationEmail do
  @moduledoc """
  Sends a confirmation email
  """
  use AshAuthentication.Sender

  require Logger

  @impl true
  def send(user, token, _) do
    Logger.debug("Confirmation request for #{user.email}, token: #{token}")
  end
end
