defmodule KwordleWeb.RoomController do
  use KwordleWeb, :controller

  def show(conn, %{"room" => room}) do
    if !Kwordle.Room.exists(room) do
      Kwordle.Room.start_room(room)
    end
    render(conn, "index.html", room: Kwordle.Room.get_a(room))
  end

  def send_word(conn, %{"room" => room}) do
    Kwordle.Room.add_a(room)
  end
end
