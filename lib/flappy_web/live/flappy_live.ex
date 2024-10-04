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
      <div :if={@game_over} class="flex flex-col items-center justify-center h-screen z-50">
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
        <p class="text-white text-4xl z-50">Score: <%= @score %></p>
      </div>
      <div id="game-area" class="game-area w-screen h-screen">
        <div
          id="bird-container"
          phx-window-keydown="player_move"
          style={"position: absolute; left: #{@bird_x_position_percentage}%; top: #{@bird_y_position_percentage}%; "}
        >
          <img src={~p"/images/flipped_phoenix.svg"} />
          <%!-- <img src={~p"/images/test_blue.svg"} /> --%>
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
      player_position: {x_position, y_position},
      game_over: game_over,
      game_height: game_height,
      score: score,
      enemies: enemies
    } =
      FlappyEngine.get_game_state()

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)
    bird_x_position_percentage = x_position / game_width * 100
    bird_y_position_percentage = y_position / game_height * 100

    updated_enemies =
      Enum.map(enemies, fn %{position: position, velocity: velocity, sprite: sprite} = enemy ->
        {x_pos, y_pos} = position
        enemy_x_position_percentage = x_pos / game_width * 100
        enemy_y_position_percentage = y_pos / game_height * 100

        %{
          enemy
          | position: {enemy_x_position_percentage, enemy_y_position_percentage},
            velocity: velocity,
            sprite: sprite
        }
      end)

    {:noreply,
     socket
     |> assign(:bird_x_position_percentage, bird_x_position_percentage)
     |> assign(:bird_y_position_percentage, bird_y_position_percentage)
     |> assign(:flappy_engine, flappy_engine_pid)
     |> assign(:enemies, updated_enemies)
     |> assign(:score, score)
     |> assign(:game_over, game_over)
     |> assign(:game_started, true)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event("play_again", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    flappy_engine_pid = GenServer.whereis(FlappyEngine) || FlappyEngine.start_engine(game_height, game_width)

    %{player_position: {x_position, y_position}, velocity: _velocity, game_over: game_over, game_height: game_height} =
      FlappyEngine.get_game_state()

    bird_y_position_percentage = y_position / game_height * 100
    bird_x_position_percentage = x_position / game_width * 100

    # Subscribe to updates
    if connected?(socket), do: Process.send_after(self(), :tick, @poll_rate)

    {:noreply,
     socket
     |> assign(:bird_y_position_percentage, bird_y_position_percentage)
     |> assign(:bird_x_position_percentage, bird_x_position_percentage)
     |> assign(:flappy_engine, flappy_engine_pid)
     |> assign(:game_over, game_over)}
  end

  def handle_event("player_move", %{"key" => "ArrowUp"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_up()

    {:noreply, socket}
  end

  def handle_event("player_move", %{"key" => "ArrowDown"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_down()

    {:noreply, socket}
  end

  def handle_event("player_move", %{"key" => "ArrowRight"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_right()

    {:noreply, socket}
  end

  def handle_event("player_move", %{"key" => "ArrowLeft"}, socket) do
    if GenServer.whereis(FlappyEngine), do: FlappyEngine.go_left()

    {:noreply, socket}
  end

  def handle_event("player_move", _, socket) do
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    %{
      player_position: {x_position, y_position},
      game_over: game_over,
      game_height: game_height,
      game_width: game_width,
      enemies: enemies,
      score: score,
      player_size: player_size
    } =
      FlappyEngine.get_game_state()

    bird_x_position_percentage = x_position / game_width * 100
    bird_y_position_percentage = y_position / game_height * 100

    updated_enemies =
      Enum.map(enemies, fn %{position: position, velocity: velocity, sprite: sprite} = enemy ->
        {x_pos, y_pos} = position
        enemy_x_position_percentage = x_pos / game_width * 100
        enemy_y_position_percentage = y_pos / game_height * 100

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
        bird_x_position_percentage,
        bird_y_position_percentage,
        game_width,
        game_height,
        player_size
      )

    if game_over or collision? do
      FlappyEngine.stop_engine()

      {:noreply,
       socket
       |> assign(:bird_y_position_percentage, bird_y_position_percentage)
       |> assign(:bird_x_position_percentage, bird_x_position_percentage)
       |> assign(:enemies, updated_enemies)
       |> assign(:game_over, true)
       |> assign(:score, score)}
    else
      Process.send_after(self(), :tick, @poll_rate)

      {:noreply,
       socket
       |> assign(:bird_y_position_percentage, bird_y_position_percentage)
       |> assign(:bird_x_position_percentage, bird_x_position_percentage)
       |> assign(:enemies, updated_enemies)
       |> assign(:score, score)}
    end
  end

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
    IO.inspect("here")

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

  # defp centre_hitbox({x, y, w, h}) do
  #   scaling_factor = 0.9
  #   scaled_width = w * scaling_factor
  #   scaled_height = h * scaling_factor
  #   quarter_width = scaled_width * (1 - scaling_factor)
  #   quarter_height = scaled_height * (1 - scaling_factor)

  #   {x + quarter_width, y + quarter_height, scaled_width - quarter_width, scaled_height - quarter_height}
  # end
end
