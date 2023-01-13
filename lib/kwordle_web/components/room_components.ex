defmodule KwordleWeb.Components.RoomComponents do
  use Phoenix.Component

  def show_word(assigns) do
    ~H"""
    <div class="grid grid-cols-5 gap-5">
      <%= for char <- String.graphemes(word_padder(@word)) do %>
        <div class="w-full aspect-square
        inline-flex justify-center items-center
        text-4xl leading-none font-bold align-middle box-border uppercase border-2">
          <%= char %>
        </div>
      <% end %>
    </div>
    """
  end

  defp word_padder(word) do
    word <> String.duplicate(" ", 5 - String.length(word))
  end
end
