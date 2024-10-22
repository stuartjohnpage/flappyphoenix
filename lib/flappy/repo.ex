defmodule Flappy.Repo do
  use Ecto.Repo,
    otp_app: :flappy,
    adapter: Ecto.Adapters.Postgres
end
