defmodule KwordleWeb.CreateRoomLive do
  use KwordleWeb, :live_view
  alias Kwordle.Room, as: Room

  def mount(_params, _session, socket) do
    {:ok, socket
      |> assign(room: "")
      |> assign(code: "")
      |> assign(room_error: true)
      |> assign(room_full: false)
      |> assign(code_error: true)
    }
  end


  def handle_event("validate", _params = %{"room" => room, "code" => code}, socket) do
    {:noreply, socket
      |> assign(room: room)
      |> assign(code: code)
      |> assign(room_error: not String.match?(room, ~r/^[a-zA-Z]+$/))
      |> assign(room_full: Room.is_full(room))
      |> assign(code_error: String.length(code) < 4)
    }
  end

  def handle_event("create-room", _params = %{"room" => room, "code" => code}, socket) do
    %{assigns: %{room_error: room_error, room_full: room_full, code_error: code_error}} = socket
    if not room_error and not room_full and not code_error do
      if not Room.exists(room) do
        Room.start_room(room, code)
        room_link = "/room/" <> room <> "/a?code=" <> code
        {:noreply, socket
          |> redirect(to: room_link)
        }
      else
        room_link = "/room/" <> room <> "/b?code=" <> code
        {:noreply, socket
          |> redirect(to: room_link)
        }
      end
    end
  end
end
