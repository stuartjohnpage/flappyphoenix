defmodule Flappy.PowerUp do
  @moduledoc """
  A module and struct to represent an power up in the game.
  It contains the position and velocity of the enemy.
  The position is a tuple of x and y coordinates, and the velocity is a tuple of x and y velocities.
  """
  alias Flappy.Explosion
  alias Flappy.Players
  alias Flappy.Position

  defstruct position: {0, 0, 0, 0},
            velocity: {0, 0},
            sprite: %{image: "", size: {0, 0}, name: :atom, chance: 0, duration: 0},
            id: ""

  @spawn_rate 400

  @power_up_sprites [
    %{image: "/images/react.svg", size: {50, 50}, name: :invincibility, chance: 50, duration: 10},
    %{image: "/images/laser.svg", size: {50, 50}, name: :laser, chance: 30, duration: 10},
    %{image: "/images/bomb.svg", size: {50, 50}, name: :bomb, chance: 20, duration: 0}
  ]

  @spec maybe_generate_power_up(%{:power_ups => any(), optional(any()) => any()}) :: any()
  def maybe_generate_power_up(%{power_ups: power_ups} = state) do
    if Enum.random(1..@spawn_rate) == 4 do
      # Generate a new power_up
      generate_power_up(state)
    else
      power_ups
    end
  end

  def generate_power_up(state) do
    half_generation_width = round(state.game_width / 2)

    [
      %__MODULE__{
        position: {Enum.random(0..half_generation_width), 0, 0, 0},
        velocity: {0, Enum.random(100..150) / state.zoom_level},
        sprite: pick_power_up(),
        id: Ecto.UUID.generate()
      }
      | state.power_ups
    ]
  end

  def power_up_sprites do
    @power_up_sprites
  end

  def update_power_ups(state) do
    power_ups =
      state
      |> maybe_generate_power_up()
      |> Enum.map(fn power_up ->
        {x, y, _x_percent, _y_percent} = power_up.position
        {vx, vy} = power_up.velocity
        new_x = x + vx * (state.game_tick_interval / 1000)
        new_y = y + vy * (state.game_tick_interval / 1000)

        {x_percent, y_percent} = Position.get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        %{power_up | position: {new_x, new_y, x_percent, y_percent}}
      end)
      |> Enum.reject(fn power_up ->
        {_x, _y, _x_percent, y} = power_up.position
        y > 100
      end)

    %{state | power_ups: power_ups}
  end

  def grant_power_ups(%{player: player} = state, power_ups_hit) do
    hit_ids = Enum.map(power_ups_hit, & &1.id)

    {power_ups, granted_powers} =
      Enum.reduce(state.power_ups, {[], player.granted_powers}, fn power_up, {power_ups, granted_powers} ->
        if power_up.id in hit_ids do
          {power_ups, [{power_up.sprite.name, power_up.sprite.duration} | granted_powers]}
        else
          {[power_up | power_ups], granted_powers}
        end
      end)

    {laser_allowed?, invincibility?} =
      Enum.reduce(granted_powers, {false, false}, fn
        {:laser, duration}, {_laser_allowed, invis} ->
          if duration > 0,
            do: {true, invis},
            else: {false, invis}

        {:invincibility, duration}, {laser_allowed, _invis} ->
          if duration > 0,
            do: {laser_allowed, true},
            else: {laser_allowed, false}

        {_invincibility, _laser_allowed}, _acc ->
          {false, false}
      end)

    {bomb_hit?, explosions} =
      Enum.reduce(power_ups_hit, {false, state.explosions}, fn power_up, {_bomb_hit, explosions} ->
        if power_up.sprite.name == :bomb do
          new_explosion = %Explosion{
            duration: 3,
            position: power_up.position,
            velocity: power_up.velocity,
            sprite: %{image: "/images/explosion.svg", size: {500, 500}, name: :explosion},
            id: Ecto.UUID.generate()
          }

          {true, [new_explosion | explosions]}
        else
          {false, explosions}
        end
      end)

    sprite =
      cond do
        laser_allowed? && invincibility? ->
          Players.get_sprite(:laser_invincibility)

        invincibility? ->
          Players.get_sprite(:invincibility)

        laser_allowed? ->
          Players.get_sprite(:laser)

        true ->
          Players.get_sprite()
      end

    {score, enemies} =
      if bomb_hit?,
        do: {player.score + length(state.enemies) * state.score_multiplier, []},
        else: {player.score, state.enemies}

    player = %{
      player
      | sprite: sprite,
        granted_powers: granted_powers,
        laser_allowed: laser_allowed?,
        invincibility: invincibility?,
        score: score
    }

    %{
      state
      | power_ups: power_ups,
        player: player,
        enemies: enemies,
        explosions: explosions
    }
  end

  defp pick_power_up do
    total_chance = Enum.sum(Enum.map(@power_up_sprites, & &1.chance))
    random = :rand.uniform() * total_chance

    Enum.reduce_while(@power_up_sprites, random, fn sprite, acc ->
      if acc <= sprite.chance do
        {:halt, sprite}
      else
        {:cont, acc - sprite.chance}
      end
    end)
  end
end
