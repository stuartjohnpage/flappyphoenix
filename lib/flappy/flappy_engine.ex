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
  alias Flappy.Hitbox
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
  @difficulty_score 500

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
    max_generation_height = round(game_height - game_height / 4)
    player = Players.create_player!(%{name: player_name, score: @start_score, version: get_game_version()})
    current_high_scores = Players.get_current_high_scores()

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
          sprite: Players.get_default_sprite(),
          granted_powers: [],
          laser_allowed: false,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false
      },
      enemies: [
        %Enemy{
          position: {game_width, Enum.random(0..max_generation_height), 100, Enum.random(0..100)},
          velocity: {Enum.random(-100..-50), 0},
          sprite: Enum.random(Enemy.get_enemy_sprites()),
          id: UUID.uuid4()
        }
      ],
      power_ups: [
        %PowerUp{
          position: {game_width / 2, 0, 50, 0},
          velocity: {0, Enum.random(50..100)},
          sprite: Enum.random(PowerUp.power_up_sprites()),
          id: UUID.uuid4()
        }
      ],
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
  def handle_info(
        :game_tick,
        %{
          game_id: game_id,
          game_height: game_height,
          game_width: game_width,
          player: %{sprite: %{size: {player_length, player_height}}} = player
        } = state
      ) do
    state =
      state
      |> Player.update_player()
      |> Enemy.update_enemies()
      |> PowerUp.update_power_ups()
      |> Explosion.update_explosions()

    {_x_pos, _y_pos, x_pos, y_pos} = player.position

    enemies_hit_by_player =
      Hitbox.check_for_enemy_collisions?(state)

    enemies_hit_by_beam =
      if state.player.laser_beam,
        do: Hitbox.get_hit_enemies(state.enemies, state),
        else: []

    power_ups_hit = Hitbox.get_hit_power_ups(state.power_ups, state)

    state =
      state
      |> Enemy.remove_hit_enemies(enemies_hit_by_beam ++ enemies_hit_by_player)
      |> PowerUp.grant_power_ups(power_ups_hit)

    collision? = if length(enemies_hit_by_player) > 0 && !state.player.invincibility, do: true, else: false

    cond do
      collision? ->
        calculate_score_and_update_view(state)

      y_pos < 0 ->
        calculate_score_and_update_view(state)

      y_pos > 100 - get_percentage(game_height, player_height) ->
        calculate_score_and_update_view(state)

      x_pos < 0 - get_percentage(game_width, player_length) ->
        calculate_score_and_update_view(state)

      x_pos > 100 ->
        calculate_score_and_update_view(state)

      true ->
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, %{player: player} = state) do
    granted_powers =
      player.granted_powers
      |> Enum.map(fn
        {_power, 0} -> nil
        {power, duration_left} -> {power, duration_left - 1}
      end)
      |> Enum.reject(&is_nil/1)

    player = %{player | score: player.score + 1, granted_powers: granted_powers}
    state = %{state | player: player}
    state = if rem(player.score, 2) == 0, do: %{state | enemies: Enemy.generate_enemy(state)}, else: state
    state = if rem(player.score, 10) == 0, do: %{state | power_ups: PowerUp.generate_power_up(state)}, else: state

    {:noreply, state}
  end

  defp calculate_score_and_update_view(
         %{player: player, game_id: game_id, current_high_scores: current_high_scores} = state
       ) do
    state = %{state | game_over: true}
    Players.update_player(player, %{score: player.score})
    high_score? = Enum.any?(current_high_scores, fn {_name, score} -> player.score > score end)

    if high_score?,
      do: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:high_score, state}),
      else: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})

    Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
    {:noreply, state}
  end

  defp get_percentage(whole, part) do
    part / whole * 100
  end

  ### PUBLIC API
  def start_engine(game_height, game_width, player_name, zoom_level) do
    game_id = UUID.uuid4()

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
