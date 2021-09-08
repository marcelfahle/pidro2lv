defmodule Pidro2lv.Repo do
  use Ecto.Repo,
    otp_app: :pidro2lv,
    adapter: Ecto.Adapters.Postgres
end
