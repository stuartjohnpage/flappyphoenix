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

  @player_size {128, 89}

  @sprites [
    # %{image: "/images/test_red.svg", size: {100, 100}}
    # %{image: "/images/ruby_on_rails-cropped.svg", size: {141, 68.6}},
    %{image: "/images/angular.svg", size: {100, 100}}
    # %{image: "/images/django.svg", size: {200, 200}},
    # %{image: "/images/ember.svg", size: {205, 77}},
    # %{image: "/images/jquery.svg", size: {200, 200}},
    # %{image: "/images/laravel.svg", size: {200, 200}},
    # %{image: "/images/react.svg", size: {100, 100}},
    # %{image: "/images/vue.svg", size: {100, 100}},
    # %{image: "/images/node.svg", size: {200, 200}}
  ]

  # Game state
  defstruct player_position: {0, 0},
            velocity: {0, 0},
            game_over: false,
            game_height: 0,
            game_width: 0,
            score: 0,
            gravity: 0,
            enemies: [],
            player_size: 0

  @impl true
  def init(%{game_height: game_height, game_width: game_width}) do
    gravity = @gravity / game_height * 500
    max_generation_height = round(game_height - game_height / 4)

    state = %__MODULE__{
      player_position: {0, game_height / 2},
      player_size: @player_size,
      velocity: @init_velocity,
      game_over: false,
      game_height: game_height,
      game_width: game_width,
      score: @start_score,
      gravity: gravity,
      enemies: [
        %Enemy{
          position: {game_width, Enum.random(0..max_generation_height)},
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

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, state) do
    state =
      state
      |> update_player()
      |> update_enemies()

    {x_pos, y_pos} = state.player_position

    cond do
      y_pos < 0 ->
        state = %{state | player_position: {x_pos, 0}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      y_pos > state.game_height - elem(@player_size, 1) ->
        state = %{
          state
          | player_position: {x_pos, state.game_height - elem(@player_size, 1)},
            velocity: {0, 0},
            game_over: true
        }

        {:noreply, state}

      x_pos < 0 ->
        state = %{state | player_position: {0, y_pos}, velocity: {0, 0}, game_over: true}
        {:noreply, state}

      x_pos > state.game_width - elem(@player_size, 0) ->
        state = %{
          state
          | player_position: {state.game_width - elem(@player_size, 0), y_pos},
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
      |> Enum.reject(fn enemy ->
        {x, _y} = enemy.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | enemies: enemies}
  end

  defp maybe_generate_enemy(%{enemies: enemies, game_height: game_height, game_width: game_width, score: score}) do
    # The game gets harder as the score increases

    difficulty_score = 50

    difficultly_rating = if score < difficulty_score - 5, do: score, else: difficulty_score - 4
    difficultly_cap = difficulty_score - difficultly_rating

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
