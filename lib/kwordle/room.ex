defmodule Kwordle.Room do
  @moduledoc """
  Context describing a room that each game of xkwordle takes place in.
  """

  @spec exists(room_name :: binary) :: boolean
  @doc """
  Check if a room exists.
  """
  def exists(room_name) do
    Registry.lookup(Kwordle.RoomRegistry, room_name) != []
  end

  @spec start_room(room_name :: binary, code :: binary) :: {:ok, pid}
  @doc """
  Start a room. The room data is stored in a map
  ```
  %{
    "a" => [ready, sees board, pid, current word, board],
    "b" => [ready, sees board, pid, current word, board],
    :target => target word,
    :winner => nil | winning player
    :code => room code
  }
  ```
  """
  def start_room(room_name, code) do
    #child = Supervisor.child_spec({Agent, fn -> [] end}, name: name)
    child = %{
      id: Agent,
      start: {
        Agent,
        :start_link,
        [
          fn ->
            %{
              "a" => generate_initial_state(),
              "b" => generate_initial_state(),
              :target => get_random_word(),
              :winner => nil,
              :code => code
            }
          end,
          [name: get_room_id(room_name)]
        ]
      }
    }
    {:ok, _agent} = DynamicSupervisor.start_child(Kwordle.RoomSupervisor, child)
  end

  @spec join_room(room_name :: binary, player :: binary, pid :: pid, code :: binary) :: :ok | :wrong_code
  @doc """
  Join a room. Returns `:ok` on success and `:wrong_code` if the code is incorrect.
  """
  def join_room(room_name, player, pid, code) do
    if correct_code(room_name, code) do
      update_room_state(
        room_name,
        fn map = %{^player => [false, false, _, word, board]} -> %{map | player => [false, false, pid, word, board]} end
      )
    else
      # This should never trigger but may as well output something
      :wrong_code
    end
  end

  @spec correct_code(room_name :: binary, code :: binary) :: boolean
  @doc """
  Check if the code for the room is correct.
  """
  def correct_code(room_name, code) do
    String.equivalent?(code, get_code(room_name))
  end

  @spec has_player_a(binary) :: boolean
  @doc """
  Check if the room already has one player in it.
  """
  def has_player_a(room_name) do
    if exists(room_name) do
      get_pid(room_name, "a") != nil
    else
      false
    end
  end

  @spec is_full(binary) :: boolean
  @doc """
  Check if the room is full (i.e. it has two players in it).
  """
  def is_full(room_name) do
    if exists(room_name) do
      get_pid(room_name, "a") != nil and get_pid(room_name, "b") != nil
    else
      false
    end
  end


  defp generate_initial_state() do
    [false, false, nil, "", []]
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


  defp get_pid(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, _sees_board, pid, _word, _board]} -> pid end)
  end

  defp get_code(room_name) do
    get_room_state(room_name, fn %{:code => code} -> code end)
  end

  defp get_hidden_word(room_name) do
    get_room_state(room_name, fn %{:target => word} -> word end)
  end

  @spec get_word(room_name :: binary, player :: binary) :: binary
  @doc """
  Get the current word the player is typing.
  """
  def get_word(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, _sees_board, _pid, word, _board]} -> word end)
  end

  @spec get_board(room_name :: binary, player :: binary) :: list(tuple)
  @doc """
  Get the player's board.
  The board consists of a list of tuples constructed in the manner `{word, colors}`.
  """
  def get_board(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, _sees_board, _pid, _word, board]} -> Enum.reverse(board) end)
  end

  @spec get_opponent_player(player :: binary) :: binary
  @doc """
  Get the opposing player.
  """
  def get_opponent_player(player) do
    case player do
      "a" -> "b"
      "b" -> "a"
    end
  end

  @spec get_winner(room_name :: binary) :: nil | binary
  @doc """
  Get the winner.
  It is `nil` if the game hasn't finished yet, `"a"` or `"b"` if a player won,
  and `"nobody"` if a stalemate occurred.
  """
  def get_winner(room_name) do
    get_room_state(room_name, fn %{:winner => winner} -> winner end)
  end

  @spec get_ready(room_name :: binary, player :: binary) :: boolean
  @doc """
  Get whether or not the player is ready.
  """
  def get_ready(room_name, player) do
    get_room_state(room_name, fn %{^player => [ready, _sees_board, _pid, _word, _board]} -> ready end)
  end

  @spec get_sees_board(room_name :: binary, player :: binary) :: boolean
  @doc """
  Get whether or not the player can see the board.
  """
  def get_sees_board(room_name, player) do
    get_room_state(room_name, fn %{^player => [_ready, sees_board, _pid, _word, _board]} -> sees_board end)
  end


  defp send_all(room_name, message) do
    send(get_pid(room_name, "a"), message)
    send(get_pid(room_name, "b"), message)
  end

  defp send_opponent(room_name, player, message) do
    opponent_pid = get_pid(room_name, get_opponent_player(player))
    send(opponent_pid, message)
  end

  @spec ready(room_name :: binary, player :: binary) :: :ok
  @doc """
  Ready up to start the game. If the first player was ready then start the game.
  """
  def ready(room_name, player) do
    if not get_ready(room_name, player) do
      # Set ready
      update_room_state(
        room_name,
        fn map = %{^player => [false, false, pid, _, _]} ->
          %{map | player => [true, false, pid, "", []]}
        end
      )
      # Tell opponent we're ready
      send_opponent(room_name, player, :check_opponent_ready)
      # If the opponent was ready start the game
      if get_ready(room_name, get_opponent_player(player)) do
        update_room_state(
          room_name,
          fn map = %{
              "a" => [true, false, pid_a, _, _],
              "b" => [true, false, pid_b, _, _]
            } ->
            %{
              map |
              "a" => [false, true, pid_a, "", []],
              "b" => [false, true, pid_b, "", []]
            }
          end
        )
        send_all(room_name, :game_start)
      end
    end
    :ok
  end

  @spec return_to_lobby(room_name :: binary, player :: binary) :: :ok
  @doc """
  Return to the lobby after a game. If the first player returned already then reset.
  """
  def return_to_lobby(room_name, player) do
    if get_sees_board(room_name, player) do
      # Return to lobby
      update_room_state(
        room_name,
        fn map = %{^player => [ready, true, pid, word, board]} ->
          %{map | player => [ready, false, pid, word, board]}
        end
      )
      # If the opponent already returned reset
      if not get_sees_board(room_name, get_opponent_player(player)) do
        update_room_state(
          room_name,
          fn map = %{
            "a" => [ready_a, false, pid_a, _, _],
            "b" => [ready_b, false, pid_b, _, _]
            } ->
            %{
              map |
              "a" => [ready_a, false, pid_a, "", []],
              "b" => [ready_b, false, pid_b, "", []],
              :target => get_random_word(),
              :winner => nil
            }
          end
        )
        send_all(room_name, :reset)
      end
    end
    :ok
  end

  @spec append_char(room_name :: binary, c :: binary, player :: binary) :: :failed | :ok
  @doc """
  Append the character c to the player's current word if possible.
  Returns `:ok` on success, else `:failed`.
  """
  def append_char(room_name, c, player) do
    if String.length(get_word(room_name, player)) < 5 and
    get_sees_board(room_name, player) and get_winner(room_name) == nil do
      update_room_state(
        room_name,
        fn map = %{^player => [ready, true, pid, word, board]} ->
          %{map | player => [ready, true, pid, word <> c, board]}
        end
      )
    else
      :failed
    end
  end

  @spec remove_char(room_name :: binary, player :: binary) :: :failed | :ok
  @doc """
  Remove a character from the player's current word if possible.
  Returns `:ok` on success, else `:failed`.
  """
  def remove_char(room_name, player) do
    len = String.length(get_word(room_name, player))
    if len > 0 and get_sees_board(room_name, player) do
      update_room_state(
        room_name,
        fn map = %{^player => [ready, true, pid, word, board]} ->
          %{map | player => [ready, true, pid, String.slice(word, 0, len - 1), board]}
        end
      )
    else
      :failed
    end
  end

  @spec submit_word(room_name :: binary, player :: binary) :: :failed | :ok
  @doc """
  Submit the current word if possible.
  Returns `:ok` on success, else `:failed`.
  """
  def submit_word(room_name, player) do
    IO.puts(get_hidden_word(room_name))
    word = get_word(room_name, player)
    if length(get_board(room_name, player)) < 6 and String.length(word) == 5 and valid_word(word) and
    get_sees_board(room_name, player) and get_winner(room_name) == nil do
      # Add word to board
      colors = check_word(get_hidden_word(room_name), word)
      update_room_state(
        room_name,
        fn map = %{^player => [ready, true, pid, word, board]} ->
          %{map | player => [ready, true, pid, "", [{word, colors} | board]]}
        end
      )

      # Check for winner
      winner = Enum.all?(colors, fn color -> color == :right end)
      if winner and get_winner(room_name) == nil do
        opponent = get_opponent_player(player)
        update_room_state(
          room_name,
          fn map = %{^opponent => [ready, true, pid, _word, board]} ->
            %{map | opponent => [ready, true, pid, "", board], :winner => player}
          end
        )
        send_all(room_name, :game_finished)
      end

      # Check if stalemate
      if not winner and
      length(get_board(room_name, player)) == 6 and
      length(get_board(room_name, get_opponent_player(player))) == 6 do
        update_room_state(
          room_name,
          fn map ->
            %{map | :winner => "nobody"}
          end
        )
        send_all(room_name, :game_finished)
      end

      # Update opponent's board
      send_opponent(room_name, player, :check_opponent_board)
      :ok
    else
      :failed
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
