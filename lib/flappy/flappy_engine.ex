defmodule Flappy.FlappyEngine do
  @moduledoc false
  use GenServer

  alias Flappy.Enemy

  # TIME VARIABLES
  @game_tick_interval 15
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @init_velocity 0
  @gravity 250
  @thrust -100
  @start_score 0

  # Game state
  defstruct bird_position: 0, velocity: 0, game_over: false, game_height: 0, game_width: 0, score: 0, gravity: 0, enemies: []

  @impl true
  def init(%{game_height: game_height, game_width: game_width}) do
    gravity = @gravity / game_height * 1000

    state = %__MODULE__{
      bird_position: game_height / 2,
      velocity: @init_velocity,
      game_over: false,
      game_height: game_height,
      game_width: game_width,
      score: @start_score,
      gravity: gravity,
      enemies: [
        %Enemy{
          position: -400,
          velocity: 100
        },
        %Enemy{
          position: -200,
          velocity: 100
        }
      ]
    }

    # Start the periodic update
    :timer.send_interval(@game_tick_interval, self(), :game_tick)
    :timer.send_interval(@score_tick_interval, self(), :score_tick)
    IO.inspect(state, label: "Initial state")
    {:ok, state}
  end

  @impl true
  def handle_call(:go_up, _from, %{velocity: velocity} = state) do
    IO.inspect(state, label: "Going up")
    new_velocity = velocity + @thrust
    {:reply, state, %{state | velocity: new_velocity}}
  end

  def handle_call(:go_down, _from, %{velocity: velocity} = state) do
    IO.inspect(state, label: "Going down")
    new_velocity = velocity - @thrust
    {:reply, state, %{state | velocity: new_velocity}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, %{game_height: game_height} = state) do

    state
    = state
    |> update_player()
    |> update_enemies()

    # Ensure the bird doesn't go below ground level (game_height from state) or above the screen  (0)
    cond do
      state.bird_position < 0 ->
        state = %{state | bird_position: 0, velocity: 0, game_over: true}
        {:noreply, state}

      state.bird_position > game_height - 100 ->
        state = %{state | bird_position: game_height, velocity: 0, game_over: true}
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, state) do
    state = %{state | score: state.score + 1}
    {:noreply, state}
  end

  defp update_player(%{bird_position: bird_position, velocity: velocity, gravity: gravity} = state) do
    # Calculate the new velocity considering gravity
    new_velocity = velocity + gravity * (@game_tick_interval / 1000)
    # Calculate the new bird_position
    new_position = bird_position + new_velocity * (@game_tick_interval / 1000)

    %{state | bird_position: new_position, velocity: new_velocity}
  end

  defp update_enemies(state) do
    enemies =
      state.enemies
      |> Enum.map(fn enemy ->
        %{enemy | position: enemy.position + enemy.velocity * (@game_tick_interval / 1000)}
      end)

    %{state | enemies: enemies}
    end

  # Public API
  def start_engine(game_height, game_width) do
    IO.inspect(game_height, label: "Game height")
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

  # defp enemies do
  # end
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
