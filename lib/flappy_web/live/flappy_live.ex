defmodule FlappyWeb.FlappyLive do
  @moduledoc false
  use FlappyWeb, :live_view

  alias Flappy.FlappyEngine

  @poll_rate 15

  def render(assigns) do
    ~H"""
    <div>
      <div
        :if={!@game_over && !@game_started}
        class="flex flex-col items-center justify-center h-screen"
      >
        <p class="text-white text-4xl">Get ready to play Flappy Phoenix!</p>
        <br />
        <p class="text-white text-2xl">Don't let the 🐦‍🔥 fly too high, or hit the ground!</p>
        <br />
        <p class="text-white text-2xl">Used the arrow keys (⬆️ and ⬇️) to move up and down!</p>
        <br />
        <p class="text-white text-2xl">👀 Good luck!</p>
        <.button phx-click="start_game" class="bg-blue-500 rounded mt-10">
          <p class="p-4 text-4xl text-white">Play</p>
        </.button>
      </div>
      <div :if={@game_over} class="flex flex-col items-center justify-center h-screen">
        <p :if={@score != 69} class="text-white text-4xl">YOU LOSE! I SAY GOOD DAY SIR!</p>
        <%!-- start Gavin's idea --%>
        <p :if={@score == 69} class="text-white text-4xl">Nice!</p>
        <%!-- end Gavin's idea --%>

        <br />
        <p class="text-white text-4xl">Your final score was <%= @score %></p>
        <.button phx-click="play_again" class="bg-blue-500 text-white px-4 py-2 rounded mt-4">
          <p class="p-4 text-4xl text-white">Play Again?</p>
        </.button>
      </div>
      <div id="score-container" class="absolute top-0 left-0 ml-11 mt-11">
        <p class="text-white text-4xl">Score: <%= @score %></p>
      </div>
      <div id="game-area" class="game-area w-screen h-screen">
        <div
          :if={!@game_over && @game_started}
          id="bird-container"
          phx-window-keydown="vertical_move"
          style={"position: absolute; top: #{@bird_position_percentage}%"}
        >
          <img src={~p"/images/phoenix_flipped.svg"} />
        </div>
        <%= for enemy <- @enemies do %>
          <div
            id="enemy-container"
            class="absolute"
            style={"position: absolute; right: #{100 - elem(enemy.position, 0) / @game_width * 100}%; top: #{elem(enemy.position, 1) / @game_height * 100}%"}
          >
            <img src={"/images/ruby_on_rails.svg"} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @spec mount(any(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    game_height = get_connect_params(socket)["viewport_height"] || 0
    game_width = get_connect_params(socket)["viewport_width"] || 0

    {:ok,
     socket
     |> assign(:enemies, [])
     |> assign(:bird_position_percentage, 0)
     |> assign(:game_over, false)
     |> assign(:game_height, game_height)
     |> assign(:game_width, game_width)
     |> assign(:game_started, false)
     |> assign(:score, 0)
     |> assign(:game_height, game_height)}
  end

  def handle_event("start_game", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    flappy_engine_pid = GenServer.whereis(FlappyEngine) || FlappyEngine.start_engine(game_height, game_width)

    %{
      bird_position: bird_position,
      game_over: game_over,
      game_height: game_height,
      score: score,
      enemies: enemies
    } =
      FlappyEngine.get_game_state()

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)

    bird_position_percentage = bird_position / game_height * 100

    {:noreply,
     socket
     |> assign(:bird_position_percentage, bird_position_percentage)
     |> assign(:flappy_engine, flappy_engine_pid)
     |> assign(:enemies, enemies)
     |> assign(:score, score)
     |> assign(:game_over, game_over)
     |> assign(:game_started, true)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event("play_again", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    flappy_engine_pid = GenServer.whereis(FlappyEngine) || FlappyEngine.start_engine(game_height, game_width)

    %{bird_position: bird_position, velocity: _velocity, game_over: game_over, game_height: game_height} =
      FlappyEngine.get_game_state()

    bird_position_percentage = bird_position / game_height * 100

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)

    {:noreply,
     socket
     |> assign(:bird_position_percentage, bird_position_percentage)
     |> assign(:flappy_engine, flappy_engine_pid)
     |> assign(:game_over, game_over)}
  end

  def handle_event("vertical_move", %{"key" => "ArrowUp"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_up()

    {:noreply, socket}
  end

  def handle_event("vertical_move", %{"key" => "ArrowDown"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_down()

    {:noreply, socket}
  end

  def handle_event("vertical_move", _, socket) do
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    %{
      bird_position: bird_position,
      game_over: game_over,
      game_height: game_height,
      enemies: enemies,
      score: score
    } =
      FlappyEngine.get_game_state()

    bird_position_percentage = bird_position / game_height * 100

    # if game_over do
    #   FlappyEngine.stop_engine()
    #   {:noreply, socket |> assign(:game_over, true) |> assign(:score, score)}
    # else
    Process.send_after(self(), :tick, @poll_rate)

    {:noreply,
     socket
     |> assign(:bird_position_percentage, bird_position_percentage)
     |> assign(:enemies, enemies)
     |> assign(:score, score)}
  end

  # end
end
