defmodule Kwordle.Room do
  @moduledoc """
  The room context.
  """
  def exists(room_name) do
    Registry.lookup(Kwordle.RoomRegistry, room_name) != []
  end

  def start_room(room_name) do
    #child = Supervisor.child_spec({Agent, fn -> [] end}, name: name)
    child = %{
      id: Agent,
      start: {
        Agent,
        :start_link,
        [
          fn -> %{:player_a => ["", []], :player_b => ["", []]} end,
          [name: get_room_id(room_name)]
        ]
      }
    }
    {:ok, _agent} = DynamicSupervisor.start_child(Kwordle.RoomSupervisor, child)
  end

  defp get_room_id(room_name) do
    {:via, Registry, {Kwordle.RoomRegistry, room_name}}
  end

  def append_char(room_name, c, :player_a) do
    if String.length(get_word(room_name, :player_a)) < 5 do
      update_room_state(
        room_name,
        fn map = %{:player_a => [word, board]} -> %{map | :player_a => [word <> c, board]} end
      )
    end
  end

  def append_char(room_name, c, :player_b) do
    if String.length(get_word(room_name, :player_b)) < 5 do
      update_room_state(
        room_name,
        fn map = %{:player_b => [word, board]} -> %{map | :player_b => [word <> c, board]} end
      )
    end
  end

  def get_word(room_name, :player_a) do
    get_room_state(room_name, fn %{:player_a => [word, _board]} -> word end)
  end

  def get_word(room_name, :player_b) do
    get_room_state(room_name, fn %{:player_b => [word, _board]} -> word end)
  end

  def get_board(room_name, :player_a) do
    get_room_state(room_name, fn %{:player_a => [_word, board]} -> Enum.reverse(board) end)
  end

  def get_board(room_name, :player_b) do
    get_room_state(room_name, fn %{:player_b => [_word, board]} -> Enum.reverse(board) end)
  end

  def remove_char(room_name, :player_a) do
    len = String.length(get_word(room_name, :player_a))
    if len > 0 do
      update_room_state(
        room_name,
        fn map = %{:player_a => [word, board]} ->
          %{map | :player_a => [String.slice(word, 0, len - 1), board]}
        end
      )
    end
  end

  def remove_char(room_name, :player_b) do
    len = String.length(get_word(room_name, :player_b))
    if len > 0 do
      update_room_state(
        room_name,
        fn map = %{:player_b => [word, board]} ->
          %{map | :player_b => [String.slice(word, 0, len - 1), board]}
        end
      )
    end
  end

  def submit_word(room_name, :player_a) do
    word = get_word(room_name, :player_a)
    if String.length(word) == 5 do
      if word in word_list() do
        IO.puts("valid word")
        update_room_state(
          room_name,
          fn map = %{:player_a => [word, board]} -> %{map | :player_a => ["", [word | board]]} end
        )
      end
    end
  end

  def submit_word(room_name, :player_b) do
    word = get_word(room_name, :player_b)
    if String.length(word) == 5 do
      if word in word_list() do
        IO.puts("valid word")
        update_room_state(
          room_name,
          fn map = %{:player_b => [_word, board]} -> %{map | :player_b => ["", [word | board]]} end
        )
      end
    end
  end

  defp get_room_state(room_name, get_f) do
    Agent.get(get_room_id(room_name), get_f)
  end

  defp update_room_state(room_name, update_f) do
    Agent.update(get_room_id(room_name), update_f)
  end

  defp word_list() do
    ["water", "hello"]
  end
end
