defmodule Flappy.GameState do
  @moduledoc """
  Encapsulated game logic extracted from FlappyEngine.
  All functions have no external side effects — no GenServer, no PubSub, no DB I/O.
  """

  alias Flappy.Enemy
  alias Flappy.Explosion
  alias Flappy.Hitbox
  alias Flappy.Players.Player
  alias Flappy.PowerUp

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
