defmodule Pidro2lvWeb.LobbyLive do
  use Pidro2lvWeb, :live_view

  alias Pidro2lv.Accounts
  alias Pidro2lvWeb.Presence

  @impl true
  def mount(_params, session, socket) do
    Pidro2lvWeb.Endpoint.subscribe("lobby")


    current_player = fetch_current_player(session)
    players = fetch_online_players()

    Presence.track(
      self(),
      "lobby",
      current_player.id,
      %{
        username: current_player.username,
        email: current_player.email,
        player_id: current_player.id,
        online_at: inspect(System.system_time(:second))
      }
    )


    {:ok,
      socket
      |> assign(current_player: current_player)
      |> assign(players: players)
    }
  end


  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    players = fetch_online_players()

    {:noreply, assign(socket, players: players)}
  end

  #
  # private functions
  #

  defp fetch_current_player(session) do
    Accounts.get_player_by_session_token(session["player_token"])
  end

  defp fetch_online_players() do
    Presence.list("lobby")
    |> Enum.map(fn {_player_id, data} ->
      data[:metas]
      |> List.first
    end)
  end

end
