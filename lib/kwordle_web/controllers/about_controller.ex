defmodule KwordleWeb.AboutController do
  use KwordleWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
