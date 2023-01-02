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
      start: {Agent, :start_link, [fn -> "Hello" end, [name: get_room(room_name)]]}
    }
    {:ok, _agent} = DynamicSupervisor.start_child(Kwordle.RoomSupervisor,
      child
      #%{:player_a => [], :player_b => []}
    )
  end

  def add_a(room_name) do
    Agent.update(get_room(room_name), fn list -> ["eggs" | list] end)
  end

  def get_a(room_name) do
    Agent.get(get_room(room_name), fn state -> state end)
  end

  defp get_room(room_name) do
    {:via, Registry, {Kwordle.RoomRegistry, room_name}}
  end
end
