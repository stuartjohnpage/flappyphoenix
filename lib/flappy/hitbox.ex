defmodule Flappy.Hitbox do
  @moduledoc """
  Hitbox functions

  You should change it so the hitbox only gets made once when the enemy is generated.

  """
  alias Flappy.Position

  def get_hit_enemies(enemies, game_state) do
    laser_hitbox = laser_hitbox(game_state)

    detect_multiple_hits(enemies, laser_hitbox, game_state)
  end

  def get_hit_power_ups(power_ups, %{player: %{sprite: %{size: player_size}, position: player_position}} = state) do
    {player_length, player_height} = player_size
    {_, _, player_x, player_y} = player_position

    player_hitbox =
      player_hitbox(player_x, player_y, player_length, player_height, state.game_width, state.game_height)

    detect_multiple_hits(power_ups, player_hitbox, state)
  end

  def check_for_enemy_collisions?(
        %{player: %{sprite: %{size: player_size}, position: player_position}, enemies: enemies} = state
      ) do
    {player_length, player_height} = player_size
    {_, _, player_x, player_y} = player_position

    player_hitbox =
      player_hitbox(player_x, player_y, player_length, player_height, state.game_width, state.game_height)

    detect_multiple_hits(enemies, player_hitbox, state)
  end

  defp detect_multiple_hits(multiple_entities, single_hitbox, game_state) do
    multiple_entities
    |> Enum.map(fn entity ->
      {_, _, entity_x, entity_y} = entity.position
      {width, height} = entity.sprite.size
      name = entity.sprite.name

      entity_hitbox =
        entity_hitbox(entity_x, entity_y, width, height, game_state.game_width, game_state.game_height, name)

      perform_detection(single_hitbox, entity_hitbox, entity)
    end)
    |> Enum.filter(& &1)
  end

  defp perform_detection(single_hitbox, entity_hitbox, entity) do
    # Broad phase
    if Polygons.Detection.collision?(single_hitbox, entity_hitbox, :fast) do
      # Narrow phase
      if Polygons.Detection.collision?(single_hitbox, entity_hitbox), do: entity
    end
  end

  defp player_hitbox(x, y, width, height, game_width, game_height) do
    w = width / game_width * 100
    h = height / game_height * 100

    point_one = {x, y + 0.6 * h}
    point_two = {x + 0.2 * w, y + 0.3 * h}
    point_three = {x + 0.8 * w, y}
    point_four = {x + w, y + 0.1 * h}
    point_five = {x + 0.8 * w, y + 0.6 * h}
    point_six = {x + 0.3 * w, y + h}

    Polygons.Polygon.make([point_one, point_two, point_three, point_four, point_five, point_six])
  end

  defp laser_hitbox(game_state) do
    x = Position.bird_x_eye_position(game_state)
    y = Position.bird_y_eye_position(game_state)
    w = 100
    h = 1

    Polygons.Polygon.make([
      {x, y},
      {x + w, y},
      {x + w, y + h},
      {w, y + h}
    ])
  end

  defp entity_hitbox(x, y, width, height, game_width, game_height, :angular) do
    w = width / game_width * 100
    h = height / game_height * 100

    left_top = {x + w * 0.1, y + 0.2 * h}
    top = {x + 0.5 * w, y}
    right_top = {x + w, y + 0.2 * h}
    right_bottom = {x + w * 0.9, y + h * 0.8}
    bottom = {x + 0.5 * w, y + h}
    left_bottom = {x + w * 0.1, y + h * 0.8}

    Polygons.Polygon.make([left_top, top, right_top, right_bottom, bottom, left_bottom])
  end

  defp entity_hitbox(x, y, width, height, game_width, game_height, :node) do
    w = width / game_width * 100
    h = height / game_height * 100

    left_top = {x, y + 0.25 * h}
    top = {x + 0.5 * w, y}
    right_top = {x + w, y + 0.25 * h}
    right_bottom = {x + w, y + h * 0.75}
    bottom = {x + 0.5 * w, y + h}
    left_bottom = {x, y + h * 0.75}

    Polygons.Polygon.make([left_top, top, right_top, right_bottom, bottom, left_bottom])
  end

  defp entity_hitbox(x, y, width, height, game_width, game_height, :ruby_rails) do
    w = width / game_width * 100
    h = height / game_height * 100

    top = {x + 0.3 * w, y}
    right_top = {x + w, y + 0.5 * h}
    right_bottom = {x + w, y + h}
    bottom = {x, y + h}
    left_bottom = {x, y + h * 0.7}

    Polygons.Polygon.make([top, right_top, right_bottom, bottom, left_bottom])
  end

  defp entity_hitbox(x, y, width, height, game_width, game_height, _) do
    w = width / game_width * 100
    h = height / game_height * 100

    tl = {x, y}
    bl = {x, y + h}
    br = {x + w, y + h}
    tr = {x + w, y}

    Polygons.Polygon.make([bl, tl, tr, br])
  end
end
