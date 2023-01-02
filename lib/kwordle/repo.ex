defmodule Kwordle.Repo do
  use Ecto.Repo,
    otp_app: :kwordle,
    adapter: Ecto.Adapters.Postgres
end
