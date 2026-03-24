defmodule Flappy.Hitbox do
  @moduledoc """
  Hitbox computation and collision detection.

  Hitbox polygons are computed once per entity per tick (after position updates)
  and cached on the entity struct. Collision detection reads the cached hitbox
  instead of recomputing it for every check.
  """
  alias Flappy.Position

  def get_hit_enemies(enemies, game_state) do
    laser_hitbox = laser_hitbox(game_state)

    detect_multiple_hits(enemies, laser_hitbox, game_state)
  end

  def get_hit_power_ups(power_ups, %{player: player} = state) do
    p_hitbox = get_or_compute_player_hitbox(player, state)
    detect_multiple_hits(power_ups, p_hitbox, state)
  end

  def check_for_enemy_collisions?(%{player: player, enemies: enemies} = state) do
    p_hitbox = get_or_compute_player_hitbox(player, state)
    detect_multiple_hits(enemies, p_hitbox, state)
  end

  defp get_or_compute_player_hitbox(%{hitbox: hitbox}, _state) when not is_nil(hitbox), do: hitbox

  defp get_or_compute_player_hitbox(player, state) do
    {player_length, player_height} = player.sprite.size
    {_, _, player_x, player_y} = player.position
    player_hitbox(player_x, player_y, player_length, player_height, state.game_width, state.game_height)
  end

  defp detect_multiple_hits(multiple_entities, single_hitbox, game_state) do
    multiple_entities
    |> Enum.map(fn entity ->
      e_hitbox = get_or_compute_entity_hitbox(entity, game_state)
      perform_detection(single_hitbox, e_hitbox, entity)
    end)
    |> Enum.filter(& &1)
  end

  defp get_or_compute_entity_hitbox(%{hitbox: hitbox}, _game_state) when not is_nil(hitbox), do: hitbox

  defp get_or_compute_entity_hitbox(entity, game_state) do
    {_, _, entity_x, entity_y} = entity.position
    {width, height} = entity.sprite.size
    name = entity.sprite.name
    entity_hitbox(entity_x, entity_y, width, height, game_state.game_width, game_state.game_height, name)
  end

  defp perform_detection(single_hitbox, entity_hitbox, entity) do
    # Broad phase
    if Polygons.Detection.collision?(single_hitbox, entity_hitbox, :fast) do
      # Narrow phase
      if Polygons.Detection.collision?(single_hitbox, entity_hitbox), do: entity
    end
  end

  def player_hitbox(x, y, width, height, game_width, game_height) do
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
      {x, y + h}
    ])
  end

  def entity_hitbox(x, y, width, height, game_width, game_height, :angular) do
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

  def entity_hitbox(x, y, width, height, game_width, game_height, :node) do
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

  def entity_hitbox(x, y, width, height, game_width, game_height, :ruby_rails) do
    w = width / game_width * 100
    h = height / game_height * 100

    top = {x + 0.3 * w, y}
    right_top = {x + w, y + 0.5 * h}
    right_bottom = {x + w, y + h}
    bottom = {x, y + h}
    left_bottom = {x, y + h * 0.7}

    Polygons.Polygon.make([top, right_top, right_bottom, bottom, left_bottom])
  end

  def entity_hitbox(x, y, width, height, game_width, game_height, _) do
    w = width / game_width * 100
    h = height / game_height * 100

    tl = {x, y}
    bl = {x, y + h}
    br = {x + w, y + h}
    tr = {x + w, y}

    Polygons.Polygon.make([bl, tl, tr, br])
  end
end
