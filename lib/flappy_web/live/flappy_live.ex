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
        <p :if={@game_state.score != 69} class="text-white text-4xl">YOU LOSE! I SAY GOOD DAY SIR!</p>
        <%!-- start Gavin's idea --%>
        <p :if={@game_state.score == 69} class="text-white text-4xl">Nice!</p>
        <%!-- end Gavin's idea --%>

        <br />
        <p class="text-white text-4xl">Your final score was <%= @game_state.score %></p>
        <.button phx-click="play_again" class="bg-blue-500 text-white px-4 py-2 rounded mt-4">
          <p class="p-4 text-4xl text-white">Play Again?</p>
        </.button>
      </div>
      <div id="score-container" class=" z-50 absolute top-0 left-0 ml-11 mt-11">
        <p class="text-white text-4xl">Score: <%= @game_state.score %></p>
      </div>
      <div id="game-area" class="game-area w-screen h-screen z-40">
        <div
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

        <%= for %{position: {x_pos, y_pos}} = enemy <- @enemies do %>
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
     |> assign(:bird_y_position_percentage, game_height / 2)
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
      game_height: game_height,
      enemies: enemies
    } = game_state = FlappyEngine.get_game_state()

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)
    {player_percentage_x, player_percentage_y} = get_percentage_position(player_position, game_width, game_height)

    updated_enemies =
      Enum.map(enemies, fn %{position: enemy_position, velocity: velocity, sprite: sprite} = enemy ->
        {enemy_x_position_percentage, enemy_y_position_percentage} =
          get_percentage_position(enemy_position, game_width, game_height)

        %{
          enemy
          | position: {enemy_x_position_percentage, enemy_y_position_percentage},
            velocity: velocity,
            sprite: sprite
        }
      end)

    {:noreply,
     socket
     |> assign(:bird_x_position_percentage, player_percentage_x)
     |> assign(:bird_y_position_percentage, player_percentage_y)
     |> assign(:enemies, updated_enemies)
     |> assign(:game_state, game_state)
     |> assign(:game_started, true)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event("play_again", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.stop_engine()
    FlappyEngine.start_engine(game_height, game_width)

    %{player_position: player_position, velocity: _velocity, game_height: game_height} =
      game_state =
      FlappyEngine.get_game_state()

    {player_percentage_x, player_percentage_y} = get_percentage_position(player_position, game_width, game_height)

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
      game_height: game_height,
      game_width: game_width,
      enemies: enemies,
      player_size: player_size
    } = game_state = FlappyEngine.get_game_state()

    {player_percentage_x, player_percentage_y} = get_percentage_position(player_position, game_width, game_height)

    updated_enemies =
      Enum.map(enemies, fn %{position: enemy_position, velocity: velocity, sprite: sprite} = enemy ->
        {enemy_x_position_percentage, enemy_y_position_percentage} =
          get_percentage_position(enemy_position, game_width, game_height)

        %{
          enemy
          | position: {enemy_x_position_percentage, enemy_y_position_percentage},
            velocity: velocity,
            sprite: sprite
        }
      end)

    collision? =
      check_for_collisions(
        updated_enemies,
        player_percentage_x,
        player_percentage_y,
        game_width,
        game_height,
        player_size
      )

    if game_state.game_over or collision? do
      FlappyEngine.stop_engine()

      {:noreply,
       socket
       |> assign(:bird_x_position_percentage, player_percentage_x)
       |> assign(:bird_y_position_percentage, player_percentage_y)
       |> assign(:enemies, updated_enemies)
       |> assign(:game_state, %{game_state | game_over: true})}
    else
      Process.send_after(self(), :tick, @poll_rate)

      IO.inspect(game_state.laser_duration)

      {:noreply,
       socket
       |> assign(:game_state, game_state)
       |> assign(:bird_x_position_percentage, player_percentage_x)
       |> assign(:bird_y_position_percentage, player_percentage_y)
       |> assign(:enemies, updated_enemies)}
    end
  end

  # Note: at this point, we are working with percentage positions here
  defp check_for_collisions(enemies, bird_x, bird_y, game_width, game_height, player_size) do
    {player_length, player_height} = player_size

    player_hitbox =
      generate_player_hitbox(bird_x, bird_y, player_length, player_height, game_width, game_height)

    Enum.any?(enemies, fn enemy ->
      {enemy_x, enemy_y} = enemy.position
      {width, height} = enemy.sprite.size
      name = enemy.sprite.name

      enemy_hitbox =
        enemy_hitbox(enemy_x, enemy_y, width, height, game_width, game_height, name)

      Polygons.Detection.collision?(player_hitbox, enemy_hitbox)
    end)
  end

  defp generate_player_hitbox(x, y, width, height, game_width, game_height) do
    w = width / game_width * 100
    h = height / game_height * 100

    point_one = {x, y + 0.6 * h}
    point_two = {x + 0.2 * w, y + 0.3 * h}
    point_three = {x + 0.8 * w, y}
    point_four = {x + w, y + 0.1 * h}
    point_five = {x + 0.8 * w, y + 0.6 * h}
    point_six = {x + 0.3 * w, y + h}

    Polygons.Polygon.make([point_one, point_two, point_three, point_four, point_five, point_six])
  end

  defp enemy_hitbox(x, y, width, height, game_width, game_height, :angular) do
    w = width / game_width * 100
    h = height / game_height * 100

    left_top = {x + w * 0.1, y + 0.2 * h}
    top = {x + 0.5 * w, y}
    right_top = {x + w, y + 0.2 * h}
    right_bottom = {x + w * 0.9, y + h * 0.8}
    bottom = {x + 0.5 * w, y + h}
    left_bottom = {x + w * 0.1, y + h * 0.8}

    Polygons.Polygon.make([left_top, top, right_top, right_bottom, bottom, left_bottom])
  end

  defp enemy_hitbox(x, y, width, height, game_width, game_height, _) do
    w = width / game_width * 100
    h = height / game_height * 100

    tl = {x, y}
    bl = {x, y + h}
    br = {x + w, y + h}
    tr = {x + w, y}

    Polygons.Polygon.make([bl, tl, tr, br])
  end

  defp get_percentage_position({x_position, y_position}, game_width, game_height) do
    percentage_x = x_position / game_width * 100
    percentage_y = y_position / game_height * 100

    {percentage_x, percentage_y}
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
