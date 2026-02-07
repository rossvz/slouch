defmodule SlouchWeb.Presence do
  use Phoenix.Presence,
    otp_app: :slouch,
    pubsub_server: Slouch.PubSub
end
