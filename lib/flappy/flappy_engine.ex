defmodule Flappy.FlappyEngine do
  @moduledoc """
  This module serves as the backbone of the FlappyPhoenix game, orchestrating all game logic and state management.

  It orchestrates:

  - Game initialization and state management
  - Player movement and controls
  - Enemy and power-up generation and updates
  - Collision detection and game-over conditions
  - Score tracking and difficulty progression
  - Periodic game state updates and broadcasts

  The engine provides a public API for starting/stopping the game, retrieving game state,
  and controlling the player's actions.
  """

  use GenServer

  alias Flappy.Enemy
  alias Flappy.Explosion
  alias Flappy.GameState
  alias Flappy.Players
  alias Flappy.Players.Player
  alias Flappy.PowerUp

  # TIME VARIABLES
  @game_tick_interval 15
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @gravity 175
  @thrust -100
  @start_score 0

  ### GAME MULTIPLIERS
  @score_multiplier 10
  @difficulty_score 400

  # Game state
  defstruct game_id: nil,
            current_high_scores: [],
            game_tick_interval: 0,
            score_tick_interval: 0,
            difficulty_score: 0,
            score_multiplier: 0,
            game_over: false,
            game_height: 0,
            game_width: 0,
            zoom_level: 1,
            gravity: 0,
            enemies: [%Enemy{}],
            power_ups: [%PowerUp{}],
            player: %Player{},
            explosions: [%Explosion{}]

  @impl true
  def init(%{
        game_height: game_height,
        game_width: game_width,
        game_id: game_id,
        player_name: player_name,
        zoom_level: zoom_level
      }) do
    gravity = @gravity / zoom_level
    player = Players.create_player!(%{name: player_name, score: @start_score, version: get_game_version()})
    current_game_version = Application.get_env(:flappy, :game_version, "1")
    current_high_scores = Players.get_current_high_scores(5, current_game_version)

    state = %__MODULE__{
      current_high_scores: current_high_scores,
      game_tick_interval: @game_tick_interval,
      score_tick_interval: @score_tick_interval,
      difficulty_score: @difficulty_score,
      score_multiplier: @score_multiplier,
      game_over: false,
      game_id: game_id,
      game_height: game_height,
      game_width: game_width,
      gravity: gravity,
      zoom_level: zoom_level,
      player: %{
        player
        | position: {100, game_height / 2, 10, 50},
          velocity: {0, 0},
          sprite: Players.get_sprite(),
          granted_powers: [],
          laser_allowed: false,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false
      },
      enemies: [],
      power_ups: [],
      explosions: []
    }

    # Start the periodic update
    :timer.send_interval(state.game_tick_interval, self(), :game_tick)
    :timer.send_interval(state.score_tick_interval, self(), :score_tick)
    {:ok, state}
  end

  @impl true
  def handle_cast(:go_up, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = y_velocity + @thrust / zoom_level
    player = %{player | velocity: {x_velocity, new_velocity}}

    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_down, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = y_velocity - @thrust / zoom_level
    player = %{player | velocity: {x_velocity, new_velocity}}

    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_right, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = x_velocity - @thrust / zoom_level
    player = %{player | velocity: {new_velocity, y_velocity}}

    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_left, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = x_velocity + @thrust / zoom_level
    player = %{player | velocity: {new_velocity, y_velocity}}

    {:noreply, %{state | player: player}}
  end

  def handle_cast(:fire_laser, %{player: player} = state) do
    if player.laser_allowed do
      player = %{player | laser_beam: true, laser_duration: 3}

      {:noreply, %{state | player: player}}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:update_viewport, zoom_level, game_width, game_height}, state) do
    {:noreply, %{state | zoom_level: zoom_level, game_width: game_width, game_height: game_height}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, %{game_id: game_id} = state) do
    case GameState.tick(state) do
      {:game_over, state} ->
        calculate_score_and_update_view(state)

      {:ok, state} ->
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, strip_hitboxes(state)})
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, state) do
    {:noreply, GameState.score_tick(state)}
  end

  defp calculate_score_and_update_view(
         %{player: player, game_id: game_id, current_high_scores: current_high_scores} = state
       ) do
    state = %{state | game_over: true}
    Players.update_player(player, %{score: player.score})
    high_score? = Enum.any?(current_high_scores, fn {_name, score} -> player.score > score end)

    broadcast_state = strip_hitboxes(state)

    if high_score?,
      do: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:high_score, broadcast_state}),
      else: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, broadcast_state})

    Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, broadcast_state})
    {:noreply, state}
  end

  defp strip_hitboxes(state) do
    %{state |
      enemies: Enum.map(state.enemies, &%{&1 | hitbox: nil}),
      power_ups: Enum.map(state.power_ups, &%{&1 | hitbox: nil}),
      player: Map.put(state.player, :hitbox, nil)
    }
  end

  ### PUBLIC API
  def start_engine(game_height, game_width, player_name, zoom_level) do
    game_id = Ecto.UUID.generate()

    GenServer.start_link(__MODULE__, %{
      game_height: game_height,
      game_width: game_width,
      game_id: game_id,
      player_name: player_name,
      zoom_level: zoom_level
    })
  end

  def stop_engine(pid) do
    GenServer.stop(pid)
  end

  def get_game_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def go_up(pid) do
    GenServer.cast(pid, :go_up)
  end

  def go_down(pid) do
    GenServer.cast(pid, :go_down)
  end

  def go_right(pid) do
    GenServer.cast(pid, :go_right)
  end

  def go_left(pid) do
    GenServer.cast(pid, :go_left)
  end

  def fire_laser(pid) do
    GenServer.cast(pid, :fire_laser)
  end

  def update_viewport(pid, zoom_level, game_width, game_height) do
    GenServer.cast(pid, {:update_viewport, zoom_level, game_width, game_height})
  end

  def get_game_version do
    Application.get_env(:flappy, :game_version, "1")
  end
end
