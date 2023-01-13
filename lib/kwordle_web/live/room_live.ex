defmodule KwordleWeb.RoomLive do
  use KwordleWeb, :live_view

  def mount(_params = %{"room" => room}, _session, socket) do
    if !Kwordle.Room.exists(room) do
      Kwordle.Room.start_room(room)
    end
    {:ok, socket
      |> assign(:room, room)
      |> assign(:str, Kwordle.Room.get_word(room, :player_a))
      |> assign(:board, [])
    }
  end

  def handle_event("key_down", _params = %{"key" => "Enter"}, socket) do
    Kwordle.Room.submit_word(socket.assigns.room, :player_a)
    {:noreply, socket
      |> assign(:str, Kwordle.Room.get_word(socket.assigns.room, :player_a))
      |> assign(:board, Kwordle.Room.get_board(socket.assigns.room, :player_a))
    }
  end

  def handle_event("key_down", _params = %{"key" => key}, socket) do
    cond do
      String.match?(key, ~r/^[a-zA-Z]$/) -> Kwordle.Room.append_char(socket.assigns.room, key, :player_a)
      key == "Backspace" or key == "Delete" -> Kwordle.Room.remove_char(socket.assigns.room, :player_a)
      true -> :nothing
    end
    {:noreply, socket
      |> assign(:str, Kwordle.Room.get_word(socket.assigns.room, :player_a))
    }
  end
end
