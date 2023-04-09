defmodule KwordleWeb.Components.RoomComponents do
  use Phoenix.Component

  def ready(assigns) do
    ~H"""
    <%= if not @game_start do %>
      <p><%= ready_text(@ready) %></p>
      <p><%= opponent_ready_text(@opponent_ready) %></p>
    <% end %>
    """
  end

  defp ready_text(ready) do
    if ready do
      "Ready!"
    else
      "Not ready! Press enter to ready"
    end
  end

  defp opponent_ready_text(opponent_ready) do
    if opponent_ready do
      "Opponent ready!"
    else
      "Opponent not ready!"
    end
  end


  def show_board(assigns) do
    ~H"""
    <%= for {word, colors} <- @board do %>
      <.show_word word={word} colors={colors} />
    <% end %>
    <%= if length(@board) < 6 do %>
      <.show_word_blank word={@cur_word} />
    <% end %>
    <%= for _ <- rest_of_board(length(@board) + 1) do %>
      <.show_word_blank word={""} />
    <% end %>
    """
  end

  def show_opponent_board(assigns) do
    ~H"""
    <%= for {_word, colors} <- @opponent_board do %>
      <.show_word word={""} colors={colors} />
    <% end %>
    <%= for _ <- rest_of_board(length(@opponent_board)) do %>
      <.show_word_blank word={""} />
    <% end %>
    """
  end

  def show_word_blank(assigns) do
    ~H"""
    <.show_word word={@word} colors={[:blank, :blank, :blank, :blank, :blank]} />
    """
  end

  def show_word(assigns) do
    ~H"""
    <div class="grid grid-cols-5 gap-5">
      <%= for {char, color} <- format_word(@word, @colors) do %>
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
      :blank -> "bg-gray-50"
      :wrong -> "bg-gray-200"
      :contained -> "bg-yellow-200"
      :right -> "bg-green-200"
    end
  end


  defp format_word(word, colors) do
    Enum.zip(String.graphemes(pad_word(word)), colors)
  end

  defp pad_word(word) do
    word <> String.duplicate(" ", 5 - String.length(word))
  end

  defp rest_of_board(board_length) do
    List.duplicate("", max(0, 6 - board_length))
  end
end
