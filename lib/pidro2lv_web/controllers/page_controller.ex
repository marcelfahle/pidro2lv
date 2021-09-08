defmodule Pidro2lvWeb.PageController do
  use Pidro2lvWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
