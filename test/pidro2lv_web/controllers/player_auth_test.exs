defmodule Pidro2lvWeb.PlayerAuthTest do
  use Pidro2lvWeb.ConnCase, async: true

  alias Pidro2lv.Accounts
  alias Pidro2lvWeb.PlayerAuth
  import Pidro2lv.AccountsFixtures

  @remember_me_cookie "_pidro2lv_web_player_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, Pidro2lvWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{player: player_fixture(), conn: conn}
  end

  describe "log_in_player/3" do
    test "stores the player token in the session", %{conn: conn, player: player} do
      conn = PlayerAuth.log_in_player(conn, player)
      assert token = get_session(conn, :player_token)
      assert get_session(conn, :live_socket_id) == "players_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert Accounts.get_player_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, player: player} do
      conn = conn |> put_session(:to_be_removed, "value") |> PlayerAuth.log_in_player(player)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, player: player} do
      conn = conn |> put_session(:player_return_to, "/hello") |> PlayerAuth.log_in_player(player)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, player: player} do
      conn = conn |> fetch_cookies() |> PlayerAuth.log_in_player(player, %{"remember_me" => "true"})
      assert get_session(conn, :player_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :player_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_player/1" do
    test "erases session and cookies", %{conn: conn, player: player} do
      player_token = Accounts.generate_player_session_token(player)

      conn =
        conn
        |> put_session(:player_token, player_token)
        |> put_req_cookie(@remember_me_cookie, player_token)
        |> fetch_cookies()
        |> PlayerAuth.log_out_player()

      refute get_session(conn, :player_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
      refute Accounts.get_player_by_session_token(player_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "players_sessions:abcdef-token"
      Pidro2lvWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> PlayerAuth.log_out_player()

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "players_sessions:abcdef-token"
      }
    end

    test "works even if player is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> PlayerAuth.log_out_player()
      refute get_session(conn, :player_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_player/2" do
    test "authenticates player from session", %{conn: conn, player: player} do
      player_token = Accounts.generate_player_session_token(player)
      conn = conn |> put_session(:player_token, player_token) |> PlayerAuth.fetch_current_player([])
      assert conn.assigns.current_player.id == player.id
    end

    test "authenticates player from cookies", %{conn: conn, player: player} do
      logged_in_conn =
        conn |> fetch_cookies() |> PlayerAuth.log_in_player(player, %{"remember_me" => "true"})

      player_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> PlayerAuth.fetch_current_player([])

      assert get_session(conn, :player_token) == player_token
      assert conn.assigns.current_player.id == player.id
    end

    test "does not authenticate if data is missing", %{conn: conn, player: player} do
      _ = Accounts.generate_player_session_token(player)
      conn = PlayerAuth.fetch_current_player(conn, [])
      refute get_session(conn, :player_token)
      refute conn.assigns.current_player
    end
  end

  describe "redirect_if_player_is_authenticated/2" do
    test "redirects if player is authenticated", %{conn: conn, player: player} do
      conn = conn |> assign(:current_player, player) |> PlayerAuth.redirect_if_player_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if player is not authenticated", %{conn: conn} do
      conn = PlayerAuth.redirect_if_player_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_player/2" do
    test "redirects if player is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> PlayerAuth.require_authenticated_player([])
      assert conn.halted
      assert redirected_to(conn) == Routes.player_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> PlayerAuth.require_authenticated_player([])

      assert halted_conn.halted
      assert get_session(halted_conn, :player_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> PlayerAuth.require_authenticated_player([])

      assert halted_conn.halted
      assert get_session(halted_conn, :player_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> PlayerAuth.require_authenticated_player([])

      assert halted_conn.halted
      refute get_session(halted_conn, :player_return_to)
    end

    test "does not redirect if player is authenticated", %{conn: conn, player: player} do
      conn = conn |> assign(:current_player, player) |> PlayerAuth.require_authenticated_player([])
      refute conn.halted
      refute conn.status
    end
  end
end