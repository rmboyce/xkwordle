defmodule KwordleWeb.Components.RoomComponents do
  use Phoenix.Component

  def show_word(assigns) do
    ~H"""
    <div class="grid grid-cols-5 gap-5">
      <%= for {char, color} <- format(@word, @colors) do %>
        <div class={"w-full aspect-square
        inline-flex justify-center items-center
        text-4xl leading-none font-bold align-middle box-border uppercase border-2
        #{color_style(color)}"}>
          <%= char %>
        </div>
      <% end %>
    </div>
    """
  end

  defp color_style(color) do
    case color do
      :empty -> "bg-gray-50"
      :wrong -> "bg-gray-200"
      :contained -> "bg-yellow-200"
      :right -> "bg-green-200"
    end
  end

  defp format(word, colors) do
    if colors != nil do
      Enum.zip(String.graphemes(word_padder(word)), colors)
    else
      Enum.map(String.graphemes(word_padder(word)), fn c -> {c, :empty} end)
    end
  end

  defp word_padder(word) do
    word <> String.duplicate(" ", 5 - String.length(word))
  end
end
