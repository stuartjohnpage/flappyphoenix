defmodule Flappy.FlappyEngine do
  @moduledoc false
  use GenServer

  alias Flappy.Enemy

  # TIME VARIABLES
  @game_tick_interval 15
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @init_velocity {0, 0}
  @gravity 250
  @thrust -100
  @start_score 0

  @sprites [
    "/images/ruby_on_rails.svg",
    "/images/angular.svg",
    "/images/django.svg",
    "/images/jquery.svg",
    "/images/laravel.svg",
    "/images/ember.svg",
    "/images/react.svg",
    "/images/vue.svg",
    "/images/node.svg"
  ]

  # Game state
  defstruct player_position: {0, 0},
            velocity: {0, 0},
            game_over: false,
            game_height: 0,
            game_width: 0,
            score: 0,
            gravity: 0,
            enemies: []

  @impl true
  def init(%{game_height: game_height, game_width: game_width}) do
    gravity = @gravity / game_height * 500

    state = %__MODULE__{
      player_position: {0, game_height / 2},
      velocity: @init_velocity,
      game_over: false,
      game_height: game_height,
      game_width: game_width,
      score: @start_score,
      gravity: gravity,
      enemies: []
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

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, %{game_height: game_height, game_width: game_width} = state) do
    state =
      state
      |> update_player()
      |> update_enemies()

    {x_pos, y_pos} = state.player_position
    # Ensure the bird doesn't go below ground level (game_height from state) or above the screen  (0)
    cond do
      # if y_pos is less than 0, set it to 0
      y_pos < 0 ->
        state = %{state | player_position: {x_pos, 0}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      # if y_pos is greater than game_height, set it to game_height
      y_pos > game_height - 100 ->
        state = %{state | player_position: {x_pos, game_height}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      # if x_pos is less than 0, set it to 0
      x_pos < 0 ->
        state = %{state | player_position: {0, y_pos}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      # if x_pos is greater than game_width, set it to game_width
      x_pos > game_width - 100 ->
        state = %{state | player_position: {game_width, y_pos}, velocity: {0, 0}, game_over: true}
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
         %{player_position: {x_position, y_position}, velocity: {x_velocity, y_velocity}, gravity: gravity} = state
       ) do
    new_y_velocity = y_velocity + gravity * (@game_tick_interval / 1000)
    new_y_position = y_position + new_y_velocity * (@game_tick_interval / 1000)
    new_x_position = x_position + x_velocity * (@game_tick_interval / 1000)

    %{state | player_position: {new_x_position, new_y_position}, velocity: {x_velocity, new_y_velocity}}
  end

  defp update_enemies(state) do
    enemies =
      state
      |> maybe_generate_enemy()
      |> Enum.map(fn enemy ->
        {x, y} = enemy.position
        {vx, vy} = enemy.velocity
        new_x = x + vx * (@game_tick_interval / 1000)
        new_y = y + vy * (@game_tick_interval / 1000)
        %{enemy | position: {new_x, new_y}}
      end)

    %{state | enemies: enemies}
  end

  defp maybe_generate_enemy(%{enemies: enemies, game_height: game_height, game_width: game_width, score: score}) do
    # The game gets harder as the score increases
    difficultly_rating = if score < 495, do: score, else: 496
    difficultly_cap = 500 - difficultly_rating

    if Enum.random(1..difficultly_cap) == 4 do
      # Generate a new enemy
      max_generation_height = round(game_height - game_height / 4)

      [
        %Enemy{
          position: {game_width, Enum.random(0..max_generation_height)},
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
end

### Thoughts I had last night

# * we should randomly generate which enemies are going to appear on the screen,
# as well as their heights and velocities.

# * we should have a way to make the game harder as the player progresses,
# this could be done by increasing the velocity of the enemies,
# or by increasing the difficulty of the obstacles.

# we should take the enemies and their speeds and heights, and
# take randomly from pools of them.

# Enemies can consist of the logos of different frameworks which compete with phoenix.
