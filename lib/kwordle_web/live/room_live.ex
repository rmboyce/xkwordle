defmodule KwordleWeb.RoomLive do
  use KwordleWeb, :live_view

  def mount(_params = %{"room" => room, "player" => player}, _session, socket) do
    if !Kwordle.Room.exists(room) do
      Kwordle.Room.start_room(room)
    end
    {:ok, socket
      |> assign(:room, room)
      |> assign(:player, player)
      |> assign(:str, "")
      |> assign(:board, [])
    }
  end

  def handle_event("key_down", _params = %{"key" => "Enter"}, socket) do
    Kwordle.Room.submit_word(socket.assigns.room, socket.assigns.player)
    {:noreply, socket
      |> assign(:str, Kwordle.Room.get_word(socket.assigns.room, socket.assigns.player))
      |> assign(:board, Kwordle.Room.get_board(socket.assigns.room, socket.assigns.player))
    }
  end

  def handle_event("key_down", _params = %{"key" => key}, socket) do
    cond do
      String.match?(key, ~r/^[a-zA-Z]$/) -> Kwordle.Room.append_char(socket.assigns.room, key, socket.assigns.player)
      key == "Backspace" or key == "Delete" -> Kwordle.Room.remove_char(socket.assigns.room, socket.assigns.player)
      true -> :nothing
    end
    {:noreply, socket
      |> assign(:str, Kwordle.Room.get_word(socket.assigns.room, socket.assigns.player))
    }
  end
end
