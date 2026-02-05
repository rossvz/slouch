defmodule Slouch.Repo do
  use Ecto.Repo,
    otp_app: :slouch,
    adapter: Ecto.Adapters.Postgres
end
