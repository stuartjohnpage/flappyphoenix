defmodule FlappyWeb.FlappyLive do
  @moduledoc false
  use FlappyWeb, :live_view

  alias Flappy.FlappyEngine

  @poll_rate 30

  def render(assigns) do
    ~H"""
    <div>
      <div
        :if={!@game_state.game_over && !@game_started}
        class="flex flex-col items-center justify-center h-screen"
      >
        <p class="text-white text-4xl">Get ready to play Flappy Phoenix!</p>
        <br />
        <p class="text-white text-2xl">Don't let the 🐦‍🔥 fly off of the screen!</p>
        <br />
        <p class="text-white text-2xl">Oh, and don't let those other frameworks touch you!</p>
        <br />
        <p class="text-white text-2xl">
          Use the arrow keys (⬆️ ⬇️ ⬅️ and ➡️ ) to move up, down, left and right!
        </p>
        <br />
        <p class="text-white text-2xl">👀 Good luck!</p>
        <.button phx-click="start_game" class="bg-blue-500 rounded mt-10">
          <p class="p-4 text-4xl text-white">Play</p>
        </.button>
      </div>
      <div :if={@game_state.game_over} class="flex flex-col items-center justify-center h-screen z-50">
        <p :if={@game_state.score != 69} class="text-white text-4xl z-50">
          YOU LOSE! I SAY GOOD DAY SIR!
        </p>
        <%!-- start Gavin's idea --%>
        <p :if={@game_state.score == 69} class="text-white text-4xl">Nice!</p>
        <%!-- end Gavin's idea --%>

        <br />
        <p class="text-white text-4xl">Your final score was <%= @game_state.score %></p>
        <.button phx-click="play_again" class="bg-blue-500 text-white px-4 py-2 rounded mt-4 z-50">
          <p class="p-4 text-4xl text-white">Play Again?</p>
        </.button>
      </div>
      <div
        id="score-container"
        class=" z-50 absolute top-0 left-0 ml-11 mt-11 bg-black rounded-md p-2"
      >
        <p class="text-white text-4xl">Score: <%= @game_state.score %></p>
      </div>
      <div id="game-area" class="game-area w-screen h-screen -z-0">
        <div
          :if={@game_started && !@game_state.game_over}
          id="bird-container"
          phx-window-keydown="player_action"
          style={"position: absolute; left: #{@bird_x_position_percentage}%; top: #{@bird_y_position_percentage}%; "}
        >
          <img src={~p"/images/flipped_phoenix.svg"} />
          <%!-- <img src={~p"/images/test_blue.svg"} /> --%>
        </div>

        <div
          :if={@game_state.laser_beam}
          id="laser-beam"
          class="absolute bg-red-500 h-1"
          style={"left: #{bird_x_eye_position(@bird_x_position_percentage, @game_state)}%; top: #{bird_y_eye_position(@bird_y_position_percentage, @game_state)}%; width: #{100 - @bird_x_position_percentage}%;"}
        >
        </div>

        <%= for %{position: {_, _, x_pos, y_pos}} = enemy <- @enemies do %>
          <div
            id={"enemy-container-#{enemy.id}"}
            class="absolute"
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%"}
          >
            <img src={enemy.sprite.image} />
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
     |> assign(:bird_x_position_percentage, 0)
     |> assign(:bird_y_position_percentage, 50)
     |> assign(:game_height, game_height)
     |> assign(:game_width, game_width)
     |> assign(:game_started, false)
     |> assign(:game_state, %FlappyEngine{})
     |> assign(:game_height, game_height)}
  end

  def handle_event("start_game", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    GenServer.whereis(FlappyEngine) || FlappyEngine.start_engine(game_height, game_width)

    %{
      player_position: player_position,
      enemies: enemies
    } = game_state = FlappyEngine.get_game_state()

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)
    {_, _, player_percentage_x, player_percentage_y} = player_position

    {:noreply,
     socket
     |> assign(:bird_x_position_percentage, player_percentage_x)
     |> assign(:bird_y_position_percentage, player_percentage_y)
     |> assign(:enemies, enemies)
     |> assign(:game_state, game_state)
     |> assign(:game_started, true)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event("play_again", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.stop_engine()
    FlappyEngine.start_engine(game_height, game_width)

    %{player_position: player_position} =
      game_state =
      FlappyEngine.get_game_state()

    {_, _, player_percentage_x, player_percentage_y} = player_position

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)

    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> assign(:bird_x_position_percentage, player_percentage_x)
     |> assign(:bird_y_position_percentage, player_percentage_y)}
  end

  def handle_event("player_action", %{"key" => "ArrowUp"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_up()

    {:noreply, socket}
  end

  def handle_event("player_action", %{"key" => "ArrowDown"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_down()

    {:noreply, socket}
  end

  def handle_event("player_action", %{"key" => "ArrowRight"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_right()

    {:noreply, socket}
  end

  def handle_event("player_action", %{"key" => "ArrowLeft"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_left()

    {:noreply, socket}
  end

  def handle_event("player_action", %{"key" => " "}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.fire_laser()

    {:noreply, socket}
  end

  def handle_event("player_action", _, socket) do
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    %{
      player_position: player_position,
      enemies: enemies
    } = game_state = FlappyEngine.get_game_state()

    {_, _, player_percentage_x, player_percentage_y} = player_position

    if game_state.game_over do
      FlappyEngine.stop_engine()

      {:noreply,
       socket
       |> assign(:bird_x_position_percentage, player_percentage_x)
       |> assign(:bird_y_position_percentage, player_percentage_y)
       |> assign(:enemies, enemies)
       |> assign(:game_state, %{game_state | game_over: true})}
    else
      Process.send_after(self(), :tick, @poll_rate)

      {:noreply,
       socket
       |> assign(:game_state, game_state)
       |> assign(:bird_x_position_percentage, player_percentage_x)
       |> assign(:bird_y_position_percentage, player_percentage_y)
       |> assign(:enemies, enemies)}
    end
  end

  defp bird_x_eye_position(x_pos, %{player_size: {w, _h}, game_width: game_width}) do
    w = w / game_width * 100
    x_pos + w * 0.81
  end

  defp bird_y_eye_position(y_pos, %{player_size: {_w, h}, game_height: game_height}) do
    h = h / game_height * 100
    y_pos + h * 0.05
  end
end
