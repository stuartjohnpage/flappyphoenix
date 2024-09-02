defmodule FlappyWeb.FlappyLive do
  use FlappyWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <div id="block-container" style="position: absolute; top: 500px">
        <img src={~p"/images/block.svg"} />
      </div>
      
      <div
        id="phoenix-container"
        phx-window-keydown="vertical_move"
        style={"position: absolute; top: #{@y_position}px"}
      >
        <img src={~p"/images/phoenix_flipped.svg"} /> <%= inspect(@y_position) %>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    # Let's assume a fixed y_position for now
    y_position = 50
    {:ok, assign(socket, :y_position, y_position)}
  end

  def handle_event("vertical_move", %{"key" => "ArrowUp"}, socket) do
    {:ok, new_position} = dec_position(socket.assigns.y_position)
    {:noreply, assign(socket, :y_position, new_position)}
  end

  def handle_event("vertical_move", %{"key" => "ArrowDown"}, socket) do
    {:ok, new_position} = inc_position(socket.assigns.y_position)
    {:noreply, assign(socket, :y_position, new_position)}
  end

  def handle_event("vertical_move", _, socket) do
    {:noreply, socket}
  end

  defp inc_position(position) when position < 500 do
    {:ok, position + 50}
  end

  defp inc_position(position) do
    {:ok, position}
  end

  defp dec_position(position) when position > 50 do
    {:ok, position - 50}
  end

  defp dec_position(position) do
    {:ok, position}
  end
end
