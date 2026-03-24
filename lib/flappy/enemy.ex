defmodule Flappy.Enemy do
  @moduledoc """
  A struct to represent an enemy in the game, and a module to contain the functions
  It contains the position and velocity of the enemy.
  The position is a tuple of x and y coordinates, and the velocity is a tuple of x and y velocities.
  """
  alias Flappy.Explosion
  alias Flappy.Hitbox
  alias Flappy.Position
  alias Flappy.PowerUp

  defstruct position: {0, 0, 0, 0}, velocity: {0, 0}, sprite: %{image: "", size: {0, 0}, name: :atom}, id: "", hitbox: nil

  @enemy_limit 300

  @enemy_sprites [
    %{image: "/images/ruby_rails.svg", size: {397, 142}, name: :ruby_rails},
    %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
    %{image: "/images/node.svg", size: {100, 100}, name: :node}
  ]

  def maybe_generate_enemy(%{enemies: enemies} = state) do
    score = effective_score(state)
    # The game gets harder as the score increases
    difficultly_rating = if score < state.difficulty_score - 5, do: score, else: state.difficulty_score - 4
    difficultly_cap = state.difficulty_score - difficultly_rating

    if Enum.random(1..difficultly_cap) == 4 && length(enemies) < @enemy_limit do
      generate_enemy(state)
    else
      enemies
    end
  end

  def generate_enemy(%{enemies: enemies, game_height: game_height, game_width: game_width, zoom_level: zoom_level}) do
    max_generation_height = game_height
    enemy_sprite = Enum.random(@enemy_sprites)
    {_enemy_width, enemy_height} = enemy_sprite.size

    [
      %__MODULE__{
        position: {game_width, Enum.random(0..(max_generation_height - enemy_height)), 100, Enum.random(0..100)},
        velocity: {Enum.random(-100..-50) / zoom_level, 0},
        sprite: enemy_sprite,
        id: Ecto.UUID.generate()
      }
      | enemies
    ]
  end

  def get_enemy_sprites do
    @enemy_sprites
  end

  def update_enemies(state) do
    enemies =
      state
      |> maybe_generate_enemy()
      |> Enum.map(fn enemy ->
        {x, y, _xpercent, _ypercent} = enemy.position
        {vx, vy} = enemy.velocity
        new_x = Float.floor(x + vx * (state.game_tick_interval / 1000), 2)
        new_y = Float.floor(y + vy * (state.game_tick_interval / 1000), 0)

        {x_percent, y_percent} = Position.get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        {w, h} = enemy.sprite.size
        hitbox = Hitbox.entity_hitbox(x_percent, y_percent, w, h, state.game_width, state.game_height, enemy.sprite.name)
        %{enemy | position: {new_x, new_y, x_percent, y_percent}, hitbox: hitbox}
      end)
      |> Enum.reject(fn enemy ->
        {x, _y, _, _} = enemy.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | enemies: enemies}
  end

  def remove_hit_enemies(state, enemies_hit, player_id) do
    hit_ids = MapSet.new(enemies_hit, & &1.id)

    {enemies, new_explosions} =
      Enum.reduce(state.enemies, {[], []}, fn enemy, {remaining, explosions} ->
        if MapSet.member?(hit_ids, enemy.id) do
          {enemy_w, enemy_h} = enemy.sprite.size
          {ex, ey, exp, eyp} = enemy.position

          # Center the explosion on the enemy
          explosion_size = 100
          x_offset = (enemy_w - explosion_size) / 2 / state.game_width * 100
          y_offset = (enemy_h - explosion_size) / 2 / state.game_height * 100

          explosion = %Explosion{
            duration: 3,
            position: {ex, ey, exp + x_offset, eyp + y_offset},
            velocity: {0, 0},
            sprite: %{image: "/images/explosion.svg", size: {explosion_size, explosion_size}, name: :explosion},
            id: Ecto.UUID.generate()
          }

          {remaining, [explosion | explosions]}
        else
          {[enemy | remaining], explosions}
        end
      end)

    player = state.players[player_id]
    updated_score = player.score + PowerUp.score_for_kills(length(new_explosions), state.score_multiplier)
    player = %{player | score: updated_score}

    %{state | enemies: enemies, explosions: new_explosions ++ state.explosions, players: Map.put(state.players, player_id, player)}
  end

  defp effective_score(%{players: players}) do
    players
    |> Map.values()
    |> Enum.filter(&Map.get(&1, :alive, true))
    |> Enum.map(& &1.score)
    |> Enum.max(fn -> 0 end)
  end
end
