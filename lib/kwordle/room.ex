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
              "a" => generate_initial_state(nil),
              "b" => generate_initial_state(nil),
              :game_start => false,
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
      fn map = %{^player => [false, _, word, board]} -> %{map | player => [false, pid, word, board]} end
    )
  end


  defp generate_initial_state(pid) do
    [false, pid, "", []]
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

  defp get_pid(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, pid, _word, _board]} -> pid end)
  end

  defp send_all(room_name, message) do
    send(get_pid(room_name, "a"), message)
    send(get_pid(room_name, "b"), message)
  end

  defp send_opponent(room_name, player, message) do
    opponent = get_opponent_player(player)
    opponent_pid = get_room_state(room_name, fn %{^opponent => [_ready, pid, _word, _board]} -> pid end)
    send(opponent_pid, message)
  end

  def get_word(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, _pid, word, _board]} -> word end)
  end

  def get_board(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, _pid, _word, board]} -> Enum.reverse(board) end)
  end

  defp get_hidden_word(room_name) do
    get_room_state(room_name, fn %{:target => word} -> word end)
  end

  def get_winner(room_name) do
    get_room_state(room_name, fn %{:winner => winner} -> winner end)
  end

  def get_ready(room_name, player) do
    get_room_state(room_name, fn %{^player => [ready, _pid, _word, _board]} -> ready end)
  end

  def ready(room_name, player) do
    update_room_state(
      room_name,
      fn map = %{^player => [_ready, pid, word, board]} ->
        %{map | player => [true, pid, word, board]}
      end
    )
    send_opponent(room_name, player, :check_opponent_ready)
    if get_ready(room_name, get_opponent_player(player)) do
      update_room_state(
        room_name,
        fn map = %{:game_start => false} ->
          %{map | :game_start => true}
        end
      )
      send_all(room_name, :game_start)
    end
  end

  def get_game_start(room_name) do
    get_room_state(room_name, fn %{:game_start => game_start} -> game_start end)
  end

  def reset(room_name) do
    update_room_state(
      room_name,
      fn map = %{"a" => [_, pid_a, _, _], "b" => [_, pid_b, _, _]} ->
        %{
          map |
          "a" => generate_initial_state(pid_a),
          "b" => generate_initial_state(pid_b),
          :game_start => false,
          :target => get_random_word(),
          :winner => nil
        }
      end
    )
    send_all(room_name, :reset)
  end

  def append_char(room_name, c, player) do
    if String.length(get_word(room_name, player)) < 5 and get_winner(room_name) == nil do
      update_room_state(
        room_name,
        fn map = %{^player => [true, pid, word, board]} ->
          %{map | player => [true, pid, word <> c, board]}
        end
      )
    end
  end

  def remove_char(room_name, player) do
    len = String.length(get_word(room_name, player))
    if len > 0 do
      update_room_state(
        room_name,
        fn map = %{^player => [true, pid, word, board]} ->
          %{map | player => [true, pid, String.slice(word, 0, len - 1), board]}
        end
      )
    end
  end

  def submit_word(room_name, player) do
    word = get_word(room_name, player)
    if length(get_board(room_name, player)) < 6 and valid_word(word) do
      colors = check_word(get_hidden_word(room_name), word)
      update_room_state(
        room_name,
        fn map = %{^player => [true, pid, word, board]} ->
          %{map | player => [true, pid, "", [{word, colors} | board]]}
        end
      )

      winner = Enum.all?(colors, fn color -> color == :right end)
      if winner and get_winner(room_name) == nil do
        opponent = get_opponent_player(player)
        update_room_state(
          room_name,
          fn map = %{^opponent => [true, pid, _word, board]} ->
            %{map | opponent => [true, pid, "", board], :winner => player}
          end
        )
        send_all(room_name, :game_finished)
      end

      send_opponent(room_name, player, :check_opponent_board)
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
