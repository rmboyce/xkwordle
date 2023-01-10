defmodule KwordleWeb.Components.RoomComponents do
  use Phoenix.Component

  def show_word(assigns) do
    ~H"""
    <p><%= @word %></p>
    """
  end
end
