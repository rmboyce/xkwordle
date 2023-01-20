defmodule Kwordle.Room do
  @moduledoc """
  Context describing a room that each game of kwordle takes place in.
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
          fn ->
            %{
              "a" => [nil, "", []],
              "b" => [nil, "", []],
              :target => get_random_word(),
              :winner => nil
            }
          end,
          [name: get_room_id(room_name)]
        ]
      }
    }
    {:ok, _agent} = DynamicSupervisor.start_child(Kwordle.RoomSupervisor, child)
    IO.puts(get_hidden_word(room_name))
  end

  def join_room(room_name, player, pid) do
    update_room_state(
      room_name,
      fn map = %{^player => [_, word, board]} -> %{map | player => [pid, word, board]} end
    )
  end


  defp get_room_id(room_name) do
    {:via, Registry, {Kwordle.RoomRegistry, room_name}}
  end

  defp get_room_state(room_name, get_fun) do
    Agent.get(get_room_id(room_name), get_fun)
  end

  defp update_room_state(room_name, update_fun) do
    Agent.update(get_room_id(room_name), update_fun)
  end


  def get_opponent_player(player) do
    case player do
      "a" -> "b"
      "b" -> "a"
    end
  end

  defp get_opponent_pid(room_name, player) do
    opponent = get_opponent_player(player)
    get_room_state(room_name, fn %{^opponent => [pid, _word, _board]} -> pid end)
  end

  defp get_pid(room_name, player) do
    get_room_state(room_name, fn %{^player => [pid, _word, _board]} -> pid end)
  end

  def get_word(room_name, player) do
    get_room_state(room_name, fn %{^player => [_pid, word, _board]} -> word end)
  end

  def get_board(room_name, player) do
    get_room_state(room_name, fn %{^player => [_pid, _word, board]} -> Enum.reverse(board) end)
  end

  defp get_hidden_word(room_name) do
    get_room_state(room_name, fn %{:target => word} -> word end)
  end

  def get_winner(room_name) do
    get_room_state(room_name, fn %{:winner => winner} -> winner end)
  end

  def append_char(room_name, c, player) do
    if String.length(get_word(room_name, player)) < 5 and get_winner(room_name) == nil do
      update_room_state(
        room_name,
        fn map = %{^player => [pid, word, board]} -> %{map | player => [pid, word <> c, board]} end
      )
    end
  end

  def remove_char(room_name, player) do
    len = String.length(get_word(room_name, player))
    if len > 0 do
      update_room_state(
        room_name,
        fn map = %{^player => [pid, word, board]} ->
          %{map | player => [pid, String.slice(word, 0, len - 1), board]}
        end
      )
    end
  end

  def submit_word(room_name, player) do
    word = get_word(room_name, player)
    board = get_board(room_name, player)
    hidden_word = get_hidden_word(room_name)
    if length(board) < 6 and valid_word(word) do
      colors = check_word(hidden_word, word)
      update_room_state(
        room_name,
        fn map = %{^player => [pid, word, board]} ->
          %{map | player => [pid, "", [{word, colors} | board]]}
        end
      )

      winner = Enum.all?(colors, fn color -> color == :right end)
      if winner and get_winner(room_name) == nil do
        opponent = get_opponent_player(player)
        update_room_state(
          room_name,
          fn map = %{^opponent => [pid, _word, board]} ->
            %{map | opponent => [pid, "", board], :winner => player}
          end
        )
        send(get_pid(room_name, player), :game_finished)
        send(get_opponent_pid(room_name, player), :game_finished)
      end

      send(get_opponent_pid(room_name, player), :check_opponent_board)
      :submitted
    end
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
