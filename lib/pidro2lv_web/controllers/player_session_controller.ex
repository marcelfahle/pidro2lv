defmodule Pidro2lvWeb.PlayerSessionController do
  use Pidro2lvWeb, :controller

  alias Pidro2lv.Accounts
  alias Pidro2lvWeb.PlayerAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"player" => player_params}) do
    %{"username" => username, "password" => password} = player_params

    if player = Accounts.get_player_by_username_and_password(username, password) do
      PlayerAuth.log_in_player(conn, player, player_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> PlayerAuth.log_out_player()
  end
end
