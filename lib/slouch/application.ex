defmodule Slouch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SlouchWeb.Telemetry,
      Slouch.Repo,
      {DNSCluster, query: Application.get_env(:slouch, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Slouch.PubSub},
      # Start a worker by calling: Slouch.Worker.start_link(arg)
      # {Slouch.Worker, arg},
      # Start to serve requests, typically the last entry
      SlouchWeb.Endpoint,
      SlouchWeb.Presence,
      {AshAuthentication.Supervisor, [otp_app: :slouch]},
      Slouch.Bots.Dispatcher
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Slouch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SlouchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
