defmodule KwordleWeb.RoomLive do
  use KwordleWeb, :live_view
  alias Kwordle.Room, as: Room
  import KwordleWeb.Components.RoomComponents

  def mount(_params = %{"room" => room, "code" => code}, _session, socket) do
    # Choose player based on whether or not room has player a
    player = if Room.has_player_a(room) do
      "b"
    else
      "a"
    end

    if not Room.correct_code(room, code) or
    connected?(socket) and Room.join_room(room, player, self(), code) == :wrong_code do
      # Wrong code, redirect to index
      {:ok, socket
        |> redirect(to: "/")
      }
    else
      # Show room
      {:ok, socket
        |> assign(:room, room)
        |> assign(:player, player)
        |> assign(:cur_word, Room.get_word(room, player))
        |> assign(:board, Room.get_board(room, player))
        |> assign(:opponent_board, Room.get_board(room, Room.get_opponent_player(player)))
        |> assign(:winner, Room.get_winner(room))
        |> assign(:ready, Room.get_ready(room, player))
        |> assign(:opponent_ready, Room.get_ready(room, Room.get_opponent_player(player)))
        |> assign(:sees_board, Room.get_sees_board(room, player))
      }
    end
  end


  def handle_info(:check_opponent_board, socket) do
    # Change opponent's board
    %{assigns: %{room: room, player: player}} = socket
    opponent_board = Room.get_board(room, Room.get_opponent_player(player))
    {:noreply, socket
      |> assign(:opponent_board, opponent_board)
    }
  end

  def handle_info(:check_opponent_ready, socket) do
    # Change opponent's ready state
    %{assigns: %{room: room, player: player}} = socket
    {:noreply, socket
      |> assign(:opponent_ready, Room.get_ready(room, Room.get_opponent_player(player)))
    }
  end

  def handle_info(:game_finished, socket) do
    # Finish game
    %{assigns: %{room: room}} = socket
    {:noreply, socket
      |> assign(:cur_word, "")
      |> assign(:winner, Room.get_winner(room))
    }
  end

  def handle_info(:game_start, socket) do
    # Start game
    %{assigns: %{room: room, player: player}} = socket
    {:noreply, socket
      |> assign(:ready, Room.get_ready(room, player))
      |> assign(:opponent_ready, Room.get_ready(room, Room.get_opponent_player(player)))
      |> assign(:sees_board, Room.get_sees_board(room, player))
    }
  end

  def handle_info(:reset, socket) do
    # Resetting game
    %{assigns: %{room: room, player: player}} = socket
    {:noreply, socket
      |> assign(:cur_word, Room.get_word(room, player))
      |> assign(:board, Room.get_board(room, player))
      |> assign(:opponent_board, Room.get_board(room, Room.get_opponent_player(player)))
      |> assign(:winner, Room.get_winner(room))
      |> assign(:ready, Room.get_ready(room, player))
      |> assign(:opponent_ready, Room.get_ready(room, Room.get_opponent_player(player)))
      |> assign(:sees_board, Room.get_sees_board(room, player))
    }
  end


  def handle_event("key_down", _params = %{"key" => "Enter"}, socket)
  when socket.assigns.sees_board and socket.assigns.winner != nil do
    # Exit to lobby
    %{assigns: %{room: room, player: player}} = socket
    Room.return_to_lobby(room, player)
    {:noreply, socket
      |> assign(:sees_board, Room.get_sees_board(room, player))
    }
  end

  def handle_event("key_down", _params = %{"key" => "Enter"}, socket)
  when socket.assigns.sees_board do
    # Submitting words
    %{assigns: %{room: room, player: player}} = socket
    Room.submit_word(room, player)
    {:noreply, socket
      |> assign(:cur_word, Room.get_word(room, player))
      |> assign(:board, Room.get_board(room, player))
    }
  end

  def handle_event("key_down", _params = %{"key" => "Enter"}, socket) do
    # Readying
    %{assigns: %{room: room, player: player}} = socket
    Room.ready(room, player)
    {:noreply, socket
      |> assign(:ready, Room.get_ready(room, player))
    }
  end

  def handle_event("key_down", _params = %{"key" => key}, socket) do
    # Entering in characters
    %{assigns: %{room: room, player: player}} = socket
    cond do
      String.match?(key, ~r/^[a-zA-Z]$/) -> Room.append_char(room, key, player)
      key == "Backspace" or key == "Delete" -> Room.remove_char(room, player)
      true -> :nothing
    end
    {:noreply, socket
      |> assign(:cur_word, Room.get_word(room, player))
    }
  end
end
