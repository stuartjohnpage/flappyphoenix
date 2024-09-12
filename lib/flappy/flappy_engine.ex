defmodule Flappy.FlappyEngine do
  @moduledoc false
  use GenServer

  # TIME VARIABLES
  @update_interval 30
  @update_score 1000

  ### VELOCITY VARIABLES
  @init_velocity 0
  @gravity 100
  @thrust -50
  @start_score 0

  defstruct position: 0, velocity: 0, game_over: false, game_height: 0, score: 0

  @impl true
  def init(%{game_height: game_height}) do
    state = %__MODULE__{
      position: game_height / 2,
      velocity: @init_velocity,
      game_over: false,
      game_height: game_height,
      score: @start_score
    }

    # Start the periodic update
    :timer.send_interval(@update_interval, self(), :update_position)
    :timer.send_interval(@update_score, self(), :update_score)
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
  def handle_info(:update_position, %{position: position, velocity: velocity, game_height: game_height} = state) do
    IO.inspect(state, label: "Game state")
    # Calculate the new velocity considering gravity
    new_velocity = velocity + @gravity * (@update_interval / 1000)
    # Calculate the new position
    new_position = position + new_velocity * (@update_interval / 1000)

    # Update the state with new position and velocity
    state = %{state | position: new_position, velocity: new_velocity}

    # Ensure the bird doesn't go below ground level (position <= 500) or above the screen  (position >= 0)
    cond do
      new_position < -100 ->
        state = %{state | position: 0, velocity: 0, game_over: true}
        {:noreply, state}

      new_position > game_height - 100 ->
        state = %{state | position: game_height, velocity: 0, game_over: true}
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(:update_score, state) do
    state = %{state | score: state.score + 1}
    {:noreply, state}
  end

  # Public API
  def start_engine(game_height) do
    IO.inspect(game_height, label: "Game height")
    GenServer.start_link(__MODULE__, %{game_height: game_height}, name: __MODULE__)
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
end
