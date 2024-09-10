defmodule FlappyWeb.FlappyLive do
  use FlappyWeb, :live_view

  alias Flappy.FlappyEngine

  @poll_rate 30

  def render(assigns) do
    ~H"""
    <div>
      <div
        :if={!@game_over && !@game_started}
        class="flex flex-col items-center justify-center h-screen"
      >
        Get ready to play Flappy Phoenix! <br />
        <br /> Don't let the 🐦‍🔥 fly too high, or hit the ground! <br />
        <br /> Used the arrow keys (⬆️ and ⬇️) to move up and down! <br />
        <br /> 👀 Good luck!
        <.button phx-click="start_game" class="bg-blue-500 text-white px-4 py-2 rounded mt-4">
          Play
        </.button>
      </div>
      <div id="game-area" class="game-area relative w-full" style={"height: #{@game_height}px;"}>
        <div
          :if={!@game_over && @game_started}
          id="phoenix-container"
          phx-window-keydown="vertical_move"
          style={"position: absolute; top: #{@bird_position_percentage}%"}
        >
          <img src={~p"/images/phoenix_flipped.svg"} />
        </div>
        <div :if={@game_over} class="flex flex-col items-center justify-center h-screen">
          YOU LOSE! I SAY GOOD DAY SIR!
          <.button phx-click="play_again" class="bg-blue-500 text-white px-4 py-2 rounded mt-4">
            Play Again?
          </.button>
        </div>
      </div>
    </div>
    """
  end

  @spec mount(any(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    game_height = FlappyEngine.get_game_height()

    {:ok,
     socket
     |> assign(:bird_position_percentage, 0)
     |> assign(:game_over, false)
     |> assign(:game_started, false)
     |> assign(:game_height, game_height)}
  end

  @spec handle_event(<<_::64, _::_*8>>, any(), any()) :: {:noreply, any()}
  def handle_event("start_game", _, socket) do
    flappy_engine_pid = FlappyEngine |> GenServer.whereis() || FlappyEngine.start_engine()

    %{position: y_position, velocity: _velocity, game_over: game_over, game_height: game_height} =
      FlappyEngine.get_game_state()

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)

    bird_position_percentage = y_position / game_height * 100

    {:noreply,
     socket
     |> assign(:bird_position_percentage, bird_position_percentage)
     |> assign(:flappy_engine, flappy_engine_pid)
     |> assign(:game_over, game_over)
     |> assign(:game_started, true)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event("play_again", _, socket) do
    flappy_engine_pid = FlappyEngine |> GenServer.whereis() || FlappyEngine.start_engine()

    %{position: y_position, velocity: _velocity, game_over: game_over, game_height: game_height} =
      FlappyEngine.get_game_state()

    bird_position_percentage = y_position / game_height * 100

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)

    {:noreply,
     socket
     |> assign(:bird_position_percentage, bird_position_percentage)
     |> assign(:flappy_engine, flappy_engine_pid)
     |> assign(:game_over, game_over)}
  end

  def handle_event("vertical_move", %{"key" => "ArrowUp"}, socket) do
    FlappyEngine.go_up()

    {:noreply, socket}
  end

  def handle_event("vertical_move", %{"key" => "ArrowDown"}, socket) do
    FlappyEngine.go_down()

    {:noreply, socket}
  end

  def handle_event("vertical_move", _, socket) do
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    %{position: y_position, velocity: _velocity, game_over: game_over, game_height: game_height} =
      FlappyEngine.get_game_state()

    bird_position_percentage = y_position / game_height * 100

    if game_over do
      FlappyEngine.stop_engine()
      {:noreply, socket |> assign(:game_over, true)}
    else
      Process.send_after(self(), :tick, @poll_rate)

      {:noreply, assign(socket, :bird_position_percentage, bird_position_percentage)}
    end
  end
end
