defmodule Pidro2lvWeb.PlayerRegistrationController do
  use Pidro2lvWeb, :controller

  alias Pidro2lv.Accounts
  alias Pidro2lv.Accounts.Player
  alias Pidro2lvWeb.PlayerAuth

  def new(conn, _params) do
    changeset = Accounts.change_player_registration(%Player{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"player" => player_params}) do
    case Accounts.register_player(player_params) do
      {:ok, player} ->
        {:ok, _} =
          Accounts.deliver_player_confirmation_instructions(
            player,
            &Routes.player_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(:info, "Player created successfully.")
        |> PlayerAuth.log_in_player(player)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
