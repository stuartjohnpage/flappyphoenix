defmodule Flappy.FlappyEngine do
  use GenServer

  @gravity -20
  @thrust 50
  @update_interval 100

  defstruct position: 0, velocity: 0

  @impl true
  def init(_args) do
    state = %__MODULE__{
      position: 0,
      velocity: 0
    }

    # Start the periodic update
    :timer.send_interval(@update_interval, self(), :update_position)
    IO.inspect(state, label: "Initial state")
    {:ok, state}
  end

  @impl true
  def handle_call(:go_up, _from, %{velocity: velocity} = state) do
    IO.inspect(state, label: "Going up")
    new_velocity = velocity + @thrust
    {:reply, state, %{state | velocity: new_velocity}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:update_position, %{position: position, velocity: velocity} = state) do
    IO.inspect(state, label: "Gravity!")
    # Calculate the new velocity considering gravity
    new_velocity = velocity + @gravity * (@update_interval / 1000)
    # Calculate the new position
    new_position = position + new_velocity * (@update_interval / 1000)

    # Update the state with new position and velocity
    state = %{state | position: new_position, velocity: new_velocity}

    # Ensure the bird doesn't go below ground level (position >= 0) or above the screen (position <= 500)
    cond do
      new_position < 0 ->
        state = %{state | position: 0, velocity: 0}
        {:noreply, state}

      new_position > 500 ->
        state = %{state | position: 500, velocity: 0}
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  # Public API
  def start_engine() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_bird_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def go_up() do
    GenServer.call(__MODULE__, :go_up)
  end
end
