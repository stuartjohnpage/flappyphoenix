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
            players: %{},
            explosions: [],
            deaths_this_tick: []

  def new(overrides \\ []) do
    player_id = Keyword.get(overrides, :player_id, Ecto.UUID.generate())

    default_player = %{
      position: {100.0, 300.0, 12.5, 50.0},
      velocity: {0.0, 0.0},
      sprite: Players.get_sprite(),
      score: 0,
      granted_powers: [],
      laser_allowed: false,
      laser_beam: false,
      laser_duration: 0,
      invincibility: false,
      hitbox: nil,
      alive: true,
      name: "",
      survival_time: 0
    }

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
      deaths_this_tick: [],
      players: %{player_id => default_player}
    }

    Enum.reduce(overrides, defaults, fn
      {:player_id, _}, acc ->
        acc

      {:player, player_overrides}, acc when is_map(player_overrides) ->
        updated_player = Map.merge(get_first_player(acc), player_overrides)
        %{acc | players: Map.put(acc.players, first_player_id(acc), updated_player)}

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  @thrust -100

  def handle_input(state, player_id, action) do
    player = state.players[player_id]
    if player == nil || !Map.get(player, :alive, true), do: state, else: do_handle_input(state, player_id, player, action)
  end

  defp do_handle_input(state, player_id, player, :go_up) do
    {x_velocity, y_velocity} = player.velocity
    put_player(state, player_id, %{player | velocity: {x_velocity, y_velocity + @thrust / state.zoom_level}})
  end

  defp do_handle_input(state, player_id, player, :go_down) do
    {x_velocity, y_velocity} = player.velocity
    put_player(state, player_id, %{player | velocity: {x_velocity, y_velocity - @thrust / state.zoom_level}})
  end

  defp do_handle_input(state, player_id, player, :go_right) do
    {x_velocity, y_velocity} = player.velocity
    put_player(state, player_id, %{player | velocity: {x_velocity - @thrust / state.zoom_level, y_velocity}})
  end

  defp do_handle_input(state, player_id, player, :go_left) do
    {x_velocity, y_velocity} = player.velocity
    put_player(state, player_id, %{player | velocity: {x_velocity + @thrust / state.zoom_level, y_velocity}})
  end

  defp do_handle_input(state, player_id, player, :fire_laser) do
    if player.laser_allowed do
      put_player(state, player_id, %{player | laser_beam: true, laser_duration: 3})
    else
      state
    end
  end

  defp do_handle_input(state, _player_id, _player, {:update_viewport, zoom_level, game_width, game_height}) do
    %{state | zoom_level: zoom_level, game_width: game_width, game_height: game_height}
  end

  def strip_hitboxes(state) do
    %{
      state
      | enemies: Enum.map(state.enemies, &%{&1 | hitbox: nil}),
        power_ups: Enum.map(state.power_ups, &%{&1 | hitbox: nil}),
        players: Map.new(state.players, fn {id, p} -> {id, Map.put(p, :hitbox, nil)} end)
    }
  end

  def tick(state) do
    state =
      state
      |> Map.put(:deaths_this_tick, [])
      |> Player.update_players()
      |> Enemy.update_enemies()
      |> PowerUp.update_power_ups()
      |> Explosion.update_explosions()

    state = resolve_collisions(state)

    alive_count =
      state.players
      |> Map.values()
      |> Enum.count(&Map.get(&1, :alive, true))

    if alive_count == 0 do
      {:game_over, %{state | game_over: true}}
    else
      {:ok, state}
    end
  end

  defp resolve_collisions(state) do
    state.players
    |> Enum.filter(fn {_id, p} -> Map.get(p, :alive, true) end)
    |> Enum.reduce(state, fn {player_id, _player}, acc_state ->
      # Re-read player from accumulated state (may have been updated by earlier iterations)
      player = acc_state.players[player_id]

      enemies_hit_by_body = Hitbox.check_for_enemy_collisions(player, acc_state.enemies, acc_state)

      enemies_hit_by_beam =
        if player.laser_beam,
          do: Hitbox.get_hit_enemies(acc_state.enemies, player, acc_state),
          else: []

      power_ups_hit = Hitbox.get_hit_power_ups(acc_state.power_ups, player, acc_state)

      acc_state =
        acc_state
        |> Enemy.remove_hit_enemies(enemies_hit_by_beam ++ enemies_hit_by_body, player_id)
        |> PowerUp.grant_power_ups(power_ups_hit, player_id)

      # Re-read player after power-ups may have changed it
      player = acc_state.players[player_id]
      body_collision? = enemies_hit_by_body != [] && !player.invincibility

      if body_collision? || out_of_bounds?(acc_state, player_id) do
        kill_player(acc_state, player_id)
      else
        acc_state
      end
    end)
  end

  def score_tick(state) do
    players =
      Map.new(state.players, fn {player_id, player} ->
        if Map.get(player, :alive, true) do
          {player_id, tick_player_score(player)}
        else
          {player_id, player}
        end
      end)

    state = %{state | players: players}

    # Use effective score (max alive player score) for enemy/power-up generation
    max_score = effective_score(state)

    state =
      if max_score > 0 && rem(max_score, 2) == 0,
        do: %{state | enemies: Enemy.maybe_generate_enemy(state)},
        else: state

    state =
      if max_score > 0 && rem(max_score, 10) == 0,
        do: %{state | power_ups: PowerUp.generate_power_up(state)},
        else: state

    state
  end

  defp tick_player_score(player) do
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

    Map.merge(player, %{
      score: player.score + 1,
      survival_time: Map.get(player, :survival_time, 0) + 1,
      granted_powers: granted_powers,
      laser_allowed: laser_allowed,
      invincibility: invincibility,
      sprite: sprite
    })
  end

  # --- Multiplayer lifecycle ---

  def add_player(state, player_id, name \\ "") do
    player = %{
      position: {100.0, state.game_height / 2, 12.5, 50.0},
      velocity: {0.0, 0.0},
      sprite: Players.get_sprite(),
      score: 0,
      granted_powers: [],
      laser_allowed: false,
      laser_beam: false,
      laser_duration: 0,
      invincibility: false,
      hitbox: nil,
      alive: true,
      name: name,
      survival_time: 0
    }

    %{state | players: Map.put(state.players, player_id, player)}
  end

  def remove_player(state, player_id) do
    player = state.players[player_id]

    explosions =
      if player && Map.get(player, :alive, true) do
        explosion = %Explosion{
          duration: 3,
          position: player.position,
          velocity: {0, 0},
          sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
          id: Ecto.UUID.generate()
        }

        [explosion | state.explosions]
      else
        state.explosions
      end

    %{state | players: Map.delete(state.players, player_id), explosions: explosions}
  end

  def crown_holder(state) do
    state.players
    |> Enum.filter(fn {_id, p} -> Map.get(p, :alive, true) end)
    |> Enum.max_by(fn {_id, p} -> Map.get(p, :survival_time, 0) end, fn -> nil end)
    |> case do
      nil -> nil
      {id, _player} -> id
    end
  end

  def last_bird_standing?(state) do
    alive =
      state.players
      |> Map.values()
      |> Enum.filter(&Map.get(&1, :alive, true))

    dead =
      state.players
      |> Map.values()
      |> Enum.reject(&Map.get(&1, :alive, true))

    length(alive) == 1 && length(dead) >= 1
  end

  def alive_count(state) do
    state.players
    |> Map.values()
    |> Enum.count(&Map.get(&1, :alive, true))
  end

  # --- Helpers ---

  defp put_player(state, player_id, player) do
    %{state | players: Map.put(state.players, player_id, player)}
  end

  defp kill_player(state, player_id) do
    player = state.players[player_id]

    explosion = %Explosion{
      duration: 3,
      position: player.position,
      velocity: {0, 0},
      sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
      id: Ecto.UUID.generate()
    }

    updated_player = Map.put(player, :alive, false)

    %{
      state
      | players: Map.put(state.players, player_id, updated_player),
        explosions: [explosion | state.explosions],
        deaths_this_tick: [player_id | state.deaths_this_tick]
    }
  end

  defp out_of_bounds?(state, player_id) do
    player = state.players[player_id]
    {_x, _y, x_pos, y_pos} = player.position
    {player_length, player_height} = player.sprite.size

    y_pos < 0 ||
      y_pos > 100 - player_height / state.game_height * 100 ||
      x_pos < 0 - player_length / state.game_width * 100 ||
      x_pos > 100
  end

  defp effective_score(%{players: players}) do
    players
    |> Map.values()
    |> Enum.filter(&Map.get(&1, :alive, true))
    |> Enum.map(& &1.score)
    |> Enum.max(fn -> 0 end)
  end

  defp first_player_id(state) do
    state.players |> Map.keys() |> List.first()
  end

  defp get_first_player(state) do
    {_id, player} = state.players |> Enum.at(0)
    player
  end
end
