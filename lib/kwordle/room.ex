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
          fn -> %{:player_a => ["", []], :player_b => ["", []], :target => get_random_word(), :winner => nil} end,
          [name: get_room_id(room_name)]
        ]
      }
    }
    {:ok, _agent} = DynamicSupervisor.start_child(Kwordle.RoomSupervisor, child)
    IO.puts(get_hidden_word(room_name))
  end

  defp get_room_id(room_name) do
    {:via, Registry, {Kwordle.RoomRegistry, room_name}}
  end

  def append_char(room_name, c, "a") do
    if String.length(get_word(room_name, "a")) < 5 and get_winner(room_name) == nil do
      update_room_state(
        room_name,
        fn map = %{:player_a => [word, board]} -> %{map | :player_a => [word <> c, board]} end
      )
    end
  end

  def append_char(room_name, c, "b") do
    if String.length(get_word(room_name, "b")) < 5 and get_winner(room_name) == nil do
      update_room_state(
        room_name,
        fn map = %{:player_b => [word, board]} -> %{map | :player_b => [word <> c, board]} end
      )
    end
  end

  def get_word(room_name, "a") do
    get_room_state(room_name, fn %{:player_a => [word, _board]} -> word end)
  end

  def get_word(room_name, "b") do
    get_room_state(room_name, fn %{:player_b => [word, _board]} -> word end)
  end

  defp get_hidden_word(room_name) do
    get_room_state(room_name, fn %{:target => word} -> word end)
  end

  def get_board(room_name, "a") do
    get_room_state(room_name, fn %{:player_a => [_word, board]} -> Enum.reverse(board) end)
  end

  def get_board(room_name, "b") do
    get_room_state(room_name, fn %{:player_b => [_word, board]} -> Enum.reverse(board) end)
  end

  def get_winner(room_name) do
    get_room_state(room_name, fn %{:winner => winner} -> winner end)
  end

  def remove_char(room_name, "a") do
    len = String.length(get_word(room_name, "a"))
    if len > 0 do
      update_room_state(
        room_name,
        fn map = %{:player_a => [word, board]} ->
          %{map | :player_a => [String.slice(word, 0, len - 1), board]}
        end
      )
    end
  end

  def remove_char(room_name, "b") do
    len = String.length(get_word(room_name, "b"))
    if len > 0 do
      update_room_state(
        room_name,
        fn map = %{:player_b => [word, board]} ->
          %{map | :player_b => [String.slice(word, 0, len - 1), board]}
        end
      )
    end
  end

  def submit_word(room_name, "a") do
    word = get_word(room_name, "a")
    board = get_board(room_name, "a")
    hidden_word = get_hidden_word(room_name)
    if length(board) < 6 and valid_word(word) do
      colors = check_word(hidden_word, word)
      update_room_state(
        room_name,
        fn map = %{:player_a => [word, board]} ->
          %{map | :player_a => ["", [{word, colors} | board]], :winner => winning_player(colors, :player_a)}
        end
      )
    end
  end

  def submit_word(room_name, "b") do
    word = get_word(room_name, "b")
    board = get_board(room_name, "b")
    hidden_word = get_hidden_word(room_name)
    if length(board) < 6 and valid_word(word) do
      colors = check_word(hidden_word, word)
      update_room_state(
        room_name,
        fn map = %{:player_b => [_word, board]} ->
          %{map | :player_b => ["", [{word, colors} | board]], :winner => winning_player(colors, :player_b)}
        end
      )
    end
  end

  defp winning_player(colors, player) do
    if Enum.all?(colors, fn color -> color == :right end) do
      player
    else
      nil
    end
  end

  defp get_room_state(room_name, get_f) do
    Agent.get(get_room_id(room_name), get_f)
  end

  defp update_room_state(room_name, update_f) do
    Agent.update(get_room_id(room_name), update_f)
  end

  defp valid_word(word) do
    String.downcase(word) in Kwordle.Words.word_list()
  end

  defp get_random_word() do
    Enum.random(Kwordle.Words.word_list())
  end

  defp check_word(hidden_word, word) do
    zipped_chars = Enum.zip(
      String.graphemes(hidden_word),
      String.graphemes(String.downcase(word))
    )
    Enum.map(zipped_chars,
      fn
        {c, c} -> :right
        {_, c} -> if String.contains?(hidden_word, c) do :contained else :wrong end
      end
    )
  end
end
