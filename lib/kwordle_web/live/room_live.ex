defmodule KwordleWeb.RoomLive do
  use KwordleWeb, :live_view

  def mount(_params = %{"room" => room}, _session, socket) do
    if !Kwordle.Room.exists(room) do
      Kwordle.Room.start_room(room)
    end
    {:ok, socket
      |> assign(:room, room)
      |> assign(:str, Kwordle.Room.get_a(room))
    }
  end

  def handle_event("key_up", _params = %{"key" => key}, socket) do
    cond do
      String.match?(key, ~r/^[a-z]$/) -> Kwordle.Room.add_a(socket.assigns.room)
      key == "Enter" -> IO.puts("pressed enter")
      true -> :nothing
    end
    {:noreply, assign(socket, :str, Kwordle.Room.get_a(socket.assigns.room))}
  end
end
