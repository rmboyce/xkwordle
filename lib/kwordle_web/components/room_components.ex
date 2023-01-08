defmodule KwordleWeb.Components.RoomComponents do
  use Phoenix.Component

  def room_id(assigns) do
    ~H"""
    <p>Current room: <%= @room %></p>
    <p><%= @str %></p>
    """
  end
end
