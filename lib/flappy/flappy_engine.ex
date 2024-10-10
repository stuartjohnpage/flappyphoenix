defmodule Flappy.FlappyEngine do
  @moduledoc false
  use GenServer

  alias Flappy.Enemy

  # TIME VARIABLES
  @game_tick_interval 30
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @init_velocity {0, 0}
  @gravity 250
  @thrust -100
  @start_score 0

  ### DIFFICULTY MULTIPLER
  @difficulty_score 5

  @player_size {128, 89}

  @sprites [
    # %{image: "/images/test_red.svg", size: {100, 100}}
    # %{image: "/images/ruby_on_rails-cropped.svg", size: {141, 68.6}},
    %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular}
    # %{image: "/images/django.svg", size: {200, 200}},
    # %{image: "/images/ember.svg", size: {205, 77}},
    # %{image: "/images/jquery.svg", size: {200, 200}},
    # %{image: "/images/laravel.svg", size: {200, 200}},
    # %{image: "/images/react.svg", size: {100, 100}},
    # %{image: "/images/vue.svg", size: {100, 100}},
    # %{image: "/images/node.svg", size: {200, 200}}
  ]

  # Game state
  # raw, raw, percent, percent
  defstruct player_position: {0, 0, 0, 0},
            velocity: {0, 0},
            game_over: false,
            game_height: 0,
            game_width: 0,
            score: 0,
            gravity: 0,
            enemies: [],
            player_size: {0, 0},
            laser_beam: false,
            laser_duration: 0

  @impl true
  def init(%{game_height: game_height, game_width: game_width}) do
    gravity = @gravity / game_height * 500
    max_generation_height = round(game_height - game_height / 4)

    state = %__MODULE__{
      player_position: {0, game_height / 2, 0, game_height / 2},
      player_size: @player_size,
      velocity: @init_velocity,
      game_over: false,
      game_height: game_height,
      game_width: game_width,
      score: @start_score,
      gravity: gravity,
      enemies: [
        %Enemy{
          position: {game_width, Enum.random(0..max_generation_height), 100, Enum.random(0..100)},
          velocity: {Enum.random(-100..-50), 0},
          sprite: Enum.random(@sprites),
          id: UUID.uuid4()
        }
      ]
    }

    # Start the periodic update
    :timer.send_interval(@game_tick_interval, self(), :game_tick)
    :timer.send_interval(@score_tick_interval, self(), :score_tick)
    {:ok, state}
  end

  @impl true
  def handle_call(:go_up, _from, %{velocity: {x_velocity, y_velocity}} = state) do
    new_velocity = y_velocity + @thrust
    {:reply, state, %{state | velocity: {x_velocity, new_velocity}}}
  end

  def handle_call(:go_down, _from, %{velocity: {x_velocity, y_velocity}} = state) do
    new_velocity = y_velocity - @thrust
    {:reply, state, %{state | velocity: {x_velocity, new_velocity}}}
  end

  def handle_call(:go_right, _from, %{velocity: {x_velocity, y_velocity}} = state) do
    new_velocity = x_velocity - @thrust
    {:reply, state, %{state | velocity: {new_velocity, y_velocity}}}
  end

  def handle_call(:go_left, _from, %{velocity: {x_velocity, y_velocity}} = state) do
    new_velocity = x_velocity + @thrust
    {:reply, state, %{state | velocity: {new_velocity, y_velocity}}}
  end

  def handle_call(:fire_laser, _from, state) do
    {:reply, :ok, %{state | laser_beam: true, laser_duration: 3}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, state) do
    state =
      state
      |> update_player()
      |> update_enemies()

    {x_pos, y_pos, x_percent, y_percent} = state.player_position

    collision? =
      check_for_collisions(
        state.enemies,
        x_percent,
        y_percent,
        state.game_width,
        state.game_height,
        state.player_size
      )

    enemies_hit_by_beam =
      if state.laser_beam,
        do: get_hit_enemies(state.enemies, x_percent, y_percent, state),
        else: []

    state = remove_hit_enemies(state, enemies_hit_by_beam)

    cond do
      collision? ->
        {:noreply, %{state | game_over: true}}

      y_pos < 0 ->
        state = %{state | player_position: {x_pos, 0, 0, 0}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      y_pos > state.game_height - elem(@player_size, 1) ->
        state = %{
          state
          | player_position: {x_pos, state.game_height - elem(@player_size, 1), 0, 0},
            velocity: {0, 0},
            game_over: true
        }

        {:noreply, state}

      x_pos < 0 ->
        state = %{state | player_position: {0, y_pos, 0, 0}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      x_pos > state.game_width - elem(@player_size, 0) ->
        state = %{
          state
          | player_position: {state.game_width - elem(@player_size, 0), y_pos, 0, 0},
            velocity: {0, 0},
            game_over: true
        }

        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, state) do
    state = %{state | score: state.score + 1}
    {:noreply, state}
  end

  defp update_player(
         %{
           player_position: {x_position, y_position, _x_percent, _y_percent},
           velocity: {x_velocity, y_velocity},
           gravity: gravity,
           game_width: game_width,
           game_height: game_height,
           laser_duration: laser_duration
         } = state
       ) do
    new_y_velocity = y_velocity + gravity * (@game_tick_interval / 1000)
    new_y_position = y_position + new_y_velocity * (@game_tick_interval / 1000)
    new_x_position = x_position + x_velocity * (@game_tick_interval / 1000)
    laser_on? = laser_duration > 0
    laser_duration = if laser_on?, do: laser_duration - 1, else: 0

    {x_percent, y_percent} = get_percentage_position({new_x_position, new_y_position}, game_width, game_height)

    %{
      state
      | player_position: {new_x_position, new_y_position, x_percent, y_percent},
        velocity: {x_velocity, new_y_velocity},
        laser_beam: laser_on?,
        laser_duration: laser_duration
    }
  end

  defp update_enemies(state) do
    enemies =
      state
      |> maybe_generate_enemy()
      |> Enum.map(fn enemy ->
        {x, y, _xpercent, _ypercent} = enemy.position
        {vx, vy} = enemy.velocity
        new_x = x + vx * (@game_tick_interval / 1000)
        new_y = y + vy * (@game_tick_interval / 1000)

        {x_percent, y_percent} = get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        %{enemy | position: {new_x, new_y, x_percent, y_percent}}
      end)
      |> Enum.reject(fn enemy ->
        {x, _y, _, _} = enemy.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | enemies: enemies}
  end

  defp maybe_generate_enemy(%{enemies: enemies, game_height: game_height, game_width: game_width, score: score}) do
    # The game gets harder as the score increases
    difficultly_rating = if score < @difficulty_score - 5, do: score, else: @difficulty_score - 4
    difficultly_cap = @difficulty_score - difficultly_rating

    if Enum.random(1..difficultly_cap) == 4 do
      # Generate a new enemy
      max_generation_height = round(game_height - game_height / 4)

      [
        %Enemy{
          position: {game_width, Enum.random(0..max_generation_height), 100, Enum.random(0..100)},
          velocity: {Enum.random(-100..-50), 0},
          sprite: Enum.random(@sprites),
          id: UUID.uuid4()
        }
        | enemies
      ]
    else
      enemies
    end
  end

  defp get_percentage_position({x_position, y_position}, game_width, game_height) do
    percentage_x = x_position / game_width * 100
    percentage_y = y_position / game_height * 100

    {percentage_x, percentage_y}
  end

  defp get_hit_enemies(enemies, player_percentage_x, player_percentage_y, game_state) do
    laser_hitbox = generate_laser_hitbox(player_percentage_x, player_percentage_y, game_state)

    Enum.filter(enemies, fn enemy ->
      {_, _, enemy_x, enemy_y} = enemy.position
      {width, height} = enemy.sprite.size
      name = enemy.sprite.name

      enemy_hitbox =
        enemy_hitbox(enemy_x, enemy_y, width, height, game_state.game_width, game_state.game_height, name)

      Polygons.Detection.collision?(laser_hitbox, enemy_hitbox)
    end)
  end

  defp generate_laser_hitbox(player_x, player_y, game_state) do
    x = bird_x_eye_position(player_x, game_state)
    y = bird_y_eye_position(player_y, game_state)
    w = 100
    h = 1

    Polygons.Polygon.make([
      {x, y},
      {x + w, y},
      {x + w, y + h},
      {w, y + h}
    ])
  end

  # Note: at this point, we are working with percentage positions here
  defp check_for_collisions(enemies, bird_x, bird_y, game_width, game_height, player_size) do
    {player_length, player_height} = player_size

    player_hitbox =
      generate_player_hitbox(bird_x, bird_y, player_length, player_height, game_width, game_height)

    Enum.any?(enemies, fn enemy ->
      {_, _, enemy_x, enemy_y} = enemy.position
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

  defp bird_x_eye_position(x_pos, %{player_size: {w, _h}, game_width: game_width}) do
    w = w / game_width * 100
    x_pos + w * 0.81
  end

  defp bird_y_eye_position(y_pos, %{player_size: {_w, h}, game_height: game_height}) do
    h = h / game_height * 100
    y_pos + h * 0.05
  end

  defp remove_hit_enemies(state, enemies_hit) do
    hit_ids = Enum.map(enemies_hit, & &1.id)
    enemies = Enum.reject(state.enemies, fn enemy -> enemy.id in hit_ids end)

    %{state | enemies: enemies}
  end

  # Public API
  def start_engine(game_height, game_width) do
    GenServer.start_link(__MODULE__, %{game_height: game_height, game_width: game_width}, name: __MODULE__)
  end

  def stop_engine do
    GenServer.stop(__MODULE__)
  end

  def get_game_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def go_up do
    GenServer.call(__MODULE__, :go_up)
  end

  def go_down do
    GenServer.call(__MODULE__, :go_down)
  end

  def go_right do
    GenServer.call(__MODULE__, :go_right)
  end

  def go_left do
    GenServer.call(__MODULE__, :go_left)
  end

  def fire_laser do
    GenServer.call(__MODULE__, :fire_laser)
  end

  def get_laser_beam_state do
    state = get_game_state()
    state.laser_beam
  end
end
