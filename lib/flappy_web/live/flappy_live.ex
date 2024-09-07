defmodule FlappyWeb.FlappyLive do
  use FlappyWeb, :live_view

  alias Flappy.FlappyEngine

  def render(assigns) do
    ~H"""
    <div>
      <%!-- <div id="block-container" style="position: absolute; top: 500px">
        <img src={~p"/images/block.svg"} />
      </div> --%>
      <%!-- <p>Position: <%= @position %></p> --%>
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
    flappy_engine_pid = FlappyEngine |> GenServer.whereis() || FlappyEngine.start_engine()
    %{position: y_position, velocity: _velocity} = FlappyEngine.get_bird_state()

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, 100)

    {:ok, socket |> assign(:y_position, y_position) |> assign(:flappy_engine, flappy_engine_pid)}
  end

  def handle_event("vertical_move", %{"key" => "ArrowUp"}, socket) do
    FlappyEngine.go_up()

    {:noreply, socket}
  end

  # def handle_event("vertical_move", %{"key" => "ArrowDown"}, socket) do
  #   {:ok, new_position} = inc_position(socket.assigns.y_position)
  #   {:noreply, assign(socket, :y_position, new_position)}
  # end

  def handle_event("vertical_move", _, socket) do
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    %{position: y_position, velocity: _velocity} = FlappyEngine.get_bird_state()
    Process.send_after(self(), :tick, 100)

    {:noreply, assign(socket, :y_position, y_position)}
  end

  # defp inc_position(position) when position < 500 do
  #   {:ok, position + 50}
  # end

  # defp inc_position(position) do
  #   {:ok, position}
  # end
end
