defmodule Flappy.FlappyEngine do
  @moduledoc false
  use GenServer

  alias Flappy.Enemy
  alias Flappy.Hitbox
  alias Flappy.Position
  alias Flappy.PowerUp

  # TIME VARIABLES
  @game_tick_interval 30
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @init_velocity {0, 0}
  @gravity 250
  @thrust -100
  @start_score 0

  @topic "flappy:game_state"

  ### DIFFICULTY MULTIPLIER
  @difficulty_score 100

  @initial_player_size {128, 89}

  @power_up_sprites [
    %{image: "/images/laser-warning.svg", size: {100, 100}, name: :laser}
  ]

  @enemy_sprites [
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
            laser_allowed: false,
            laser_beam: false,
            laser_duration: 0,
            power_ups: [],
            granted_powers: []

  @impl true
  def init(%{game_height: game_height, game_width: game_width}) do
    gravity = @gravity / game_height * 500
    max_generation_height = round(game_height - game_height / 4)

    state = %__MODULE__{
      player_position: {0, game_height / 2, 0, game_height / 2},
      player_size: @initial_player_size,
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
          sprite: Enum.random(@enemy_sprites),
          id: UUID.uuid4()
        }
      ],
      power_ups: [
        %PowerUp{
          position: {game_width / 2, 0, 50, 0},
          velocity: {0, Enum.random(50..100)},
          sprite: Enum.random(@power_up_sprites),
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
    if state.laser_allowed do
      {:reply, :ok, %{state | laser_beam: true, laser_duration: 3}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, %{player_size: {player_length, player_height}} = state) do
    state =
      state
      |> update_player()
      |> update_enemies()
      |> update_power_ups()

    {x_pos, y_pos, _, _} = state.player_position

    collision? =
      Hitbox.check_for_enemy_collisions?(state)

    enemies_hit_by_beam =
      if state.laser_beam,
        do: Hitbox.get_hit_enemies(state.enemies, state),
        else: []

    power_ups_hit = Hitbox.get_hit_power_ups(state.power_ups, state)

    state =
      state
      |> Hitbox.remove_hit_enemies(enemies_hit_by_beam)
      |> grant_power_ups(power_ups_hit)

    cond do
      collision? ->
        state = %{state | game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, @topic, {:game_state_update, state})
        {:noreply, state}

      y_pos < 0 ->
        state = %{state | player_position: {x_pos, 0, 0, 0}, velocity: {0, 0}, game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, @topic, {:game_state_update, state})
        {:noreply, state}

      y_pos > state.game_height - player_height ->
        state = %{
          state
          | player_position: {x_pos, state.game_height - player_height, 0, 0},
            velocity: {0, 0},
            game_over: true
        }

        Phoenix.PubSub.broadcast(Flappy.PubSub, @topic, {:game_state_update, state})
        {:noreply, state}

      x_pos < 0 ->
        state = %{state | player_position: {0, y_pos, 0, 0}, velocity: {0, 0}, game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, @topic, {:game_state_update, state})
        {:noreply, state}

      x_pos > state.game_width - player_length ->
        state = %{
          state
          | player_position: {state.game_width - player_length, y_pos, 0, 0},
            velocity: {0, 0},
            game_over: true
        }

        Phoenix.PubSub.broadcast(Flappy.PubSub, @topic, {:game_state_update, state})
        {:noreply, state}

      true ->
        Phoenix.PubSub.broadcast(Flappy.PubSub, @topic, {:game_state_update, state})
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, state) do
    granted_powers =
      state.granted_powers
      |> Enum.map(fn
        {_power, 0} -> nil
        {power, duration_left} -> {power, duration_left - 1}
      end)
      |> Enum.reject(&is_nil(&1))

    state = %{state | score: state.score + 1, granted_powers: granted_powers}

    {:noreply, state}
  end

  ## PRIVATE FUNCTIONS

  ### UPDATE FUNCTIONS

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

    {x_percent, y_percent} = Position.get_percentage_position({new_x_position, new_y_position}, game_width, game_height)

    %{
      state
      | player_position: {new_x_position, new_y_position, x_percent, y_percent},
        velocity: {x_velocity, new_y_velocity},
        laser_beam: laser_on?,
        laser_duration: laser_duration
    }
  end

  defp update_power_ups(state) do
    power_ups =
      state
      |> maybe_generate_power_up()
      |> Enum.map(fn power_up ->
        {x, y, _xpercent, _ypercent} = power_up.position
        {vx, vy} = power_up.velocity
        new_x = x + vx * (@game_tick_interval / 1000)
        new_y = y + vy * (@game_tick_interval / 1000)

        {x_percent, y_percent} = Position.get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        %{power_up | position: {new_x, new_y, x_percent, y_percent}}
      end)
      |> Enum.reject(fn power_up ->
        {x, _y, _, _} = power_up.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | power_ups: power_ups}
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

        {x_percent, y_percent} = Position.get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        %{enemy | position: {new_x, new_y, x_percent, y_percent}}
      end)
      |> Enum.reject(fn enemy ->
        {x, _y, _, _} = enemy.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | enemies: enemies}
  end

  defp grant_power_ups(state, power_ups_hit) do
    hit_ids = Enum.map(power_ups_hit, & &1.id)

    {power_ups, granted_powers} =
      Enum.reduce(state.power_ups, {[], state.granted_powers}, fn power_up, {power_ups, granted_powers} ->
        if power_up.id in hit_ids do
          {power_ups, [{power_up.sprite.name, 5} | granted_powers]}
        else
          {[power_up | power_ups], granted_powers}
        end
      end)

    laser_allowed =
      Enum.any?(granted_powers, fn
        {:laser, duration} when duration > 0 -> true
        _ -> false
      end)

    %{state | power_ups: power_ups, granted_powers: granted_powers, laser_allowed: laser_allowed}
  end

  ### GENERATION FUNCTIONS

  defp maybe_generate_power_up(%{power_ups: power_ups, game_width: game_width}) do
    if Enum.random(1..1000) == 4 do
      # Generate a new power_up
      [
        %PowerUp{
          position: {game_width / 2, 0, 50, 0},
          velocity: {0, Enum.random(100..150)},
          sprite: Enum.random(@power_up_sprites),
          id: UUID.uuid4()
        }
        | power_ups
      ]
    else
      power_ups
    end
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
          sprite: Enum.random(@enemy_sprites),
          id: UUID.uuid4()
        }
        | enemies
      ]
    else
      enemies
    end
  end

  ### PUBLIC API
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
end
