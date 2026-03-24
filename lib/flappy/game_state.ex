defmodule Flappy.GameState do
  @moduledoc """
  Pure game state machine. All functions take state in, return state out.
  No side effects — no GenServer, no PubSub, no DB I/O.
  """

  alias Flappy.Enemy
  alias Flappy.Explosion
  alias Flappy.Hitbox
  alias Flappy.Players
  alias Flappy.Players.Player
  alias Flappy.PowerUp

  @gravity 175
  @game_tick_interval 15
  @score_tick_interval 1000
  @score_multiplier 10
  @difficulty_score 400

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
            enemies: [],
            power_ups: [],
            player: %{
              position: {0, 0, 0, 0},
              velocity: {0.0, 0.0},
              sprite: %{image: "", size: {0, 0}, name: :default},
              score: 0,
              granted_powers: [],
              laser_allowed: false,
              laser_beam: false,
              laser_duration: 0,
              invincibility: false
            },
            explosions: []

  def new(overrides \\ []) do
    defaults = %__MODULE__{
      game_id: Ecto.UUID.generate(),
      game_tick_interval: @game_tick_interval,
      score_tick_interval: @score_tick_interval,
      score_multiplier: @score_multiplier,
      difficulty_score: @difficulty_score,
      game_over: false,
      game_height: 600,
      game_width: 800,
      zoom_level: 1,
      gravity: @gravity,
      enemies: [],
      power_ups: [],
      explosions: [],
      player: %{
        position: {100.0, 300.0, 12.5, 50.0},
        velocity: {0.0, 0.0},
        sprite: Players.get_sprite(),
        score: 0,
        granted_powers: [],
        laser_allowed: false,
        laser_beam: false,
        laser_duration: 0,
        invincibility: false
      }
    }

    Enum.reduce(overrides, defaults, fn
      {:player, player_overrides}, acc when is_map(player_overrides) ->
        %{acc | player: Map.merge(acc.player, player_overrides)}

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  @thrust -100

  def handle_input(%{player: player, zoom_level: zoom_level} = state, :go_up) do
    {x_velocity, y_velocity} = player.velocity
    %{state | player: %{player | velocity: {x_velocity, y_velocity + @thrust / zoom_level}}}
  end

  def handle_input(%{player: player, zoom_level: zoom_level} = state, :go_down) do
    {x_velocity, y_velocity} = player.velocity
    %{state | player: %{player | velocity: {x_velocity, y_velocity - @thrust / zoom_level}}}
  end

  def handle_input(%{player: player, zoom_level: zoom_level} = state, :go_right) do
    {x_velocity, y_velocity} = player.velocity
    %{state | player: %{player | velocity: {x_velocity - @thrust / zoom_level, y_velocity}}}
  end

  def handle_input(%{player: player, zoom_level: zoom_level} = state, :go_left) do
    {x_velocity, y_velocity} = player.velocity
    %{state | player: %{player | velocity: {x_velocity + @thrust / zoom_level, y_velocity}}}
  end

  def handle_input(%{player: player} = state, :fire_laser) do
    if player.laser_allowed do
      %{state | player: %{player | laser_beam: true, laser_duration: 3}}
    else
      state
    end
  end

  def handle_input(state, {:update_viewport, zoom_level, game_width, game_height}) do
    %{state | zoom_level: zoom_level, game_width: game_width, game_height: game_height}
  end

  def strip_hitboxes(state) do
    %{
      state
      | enemies: Enum.map(state.enemies, &%{&1 | hitbox: nil}),
        power_ups: Enum.map(state.power_ups, &%{&1 | hitbox: nil}),
        player: Map.put(state.player, :hitbox, nil)
    }
  end

  def tick(state) do
    state =
      state
      |> Player.update_player()
      |> Enemy.update_enemies()
      |> PowerUp.update_power_ups()
      |> Explosion.update_explosions()

    enemies_hit_by_player = Hitbox.check_for_enemy_collisions?(state)

    enemies_hit_by_beam =
      if state.player.laser_beam,
        do: Hitbox.get_hit_enemies(state.enemies, state),
        else: []

    power_ups_hit = Hitbox.get_hit_power_ups(state.power_ups, state)

    state =
      state
      |> Enemy.remove_hit_enemies(enemies_hit_by_beam ++ enemies_hit_by_player)
      |> PowerUp.grant_power_ups(power_ups_hit)

    collision? = enemies_hit_by_player != [] && !state.player.invincibility

    if collision? || out_of_bounds?(state) do
      {:game_over, %{state | game_over: true}}
    else
      {:ok, state}
    end
  end

  def score_tick(%{player: player} = state) do
    granted_powers =
      player.granted_powers
      |> Enum.uniq_by(fn {power, _duration} -> power end)
      |> Enum.map(fn
        {_power, 0} -> nil
        {power, duration_left} -> {power, duration_left - 1}
      end)
      |> Enum.reject(&is_nil/1)

    %{laser_allowed: laser_allowed, invincibility: invincibility, sprite: sprite} =
      PowerUp.derive_power_flags(granted_powers)

    player =
      Map.merge(player, %{
        score: player.score + 1,
        granted_powers: granted_powers,
        laser_allowed: laser_allowed,
        invincibility: invincibility,
        sprite: sprite
      })

    state = %{state | player: player}
    state = if rem(player.score, 2) == 0, do: %{state | enemies: Enemy.maybe_generate_enemy(state)}, else: state
    state = if rem(player.score, 10) == 0, do: %{state | power_ups: PowerUp.generate_power_up(state)}, else: state

    state
  end

  defp out_of_bounds?(%{
         player: %{position: {_x, _y, x_pos, y_pos}, sprite: %{size: {player_length, player_height}}},
         game_width: game_width,
         game_height: game_height
       }) do
    y_pos < 0 ||
      y_pos > 100 - player_height / game_height * 100 ||
      x_pos < 0 - player_length / game_width * 100 ||
      x_pos > 100
  end
end
