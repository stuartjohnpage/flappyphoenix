defmodule Flappy.HitboxCacheTest do
  use ExUnit.Case, async: true

  alias Flappy.Hitbox

  @game_width 800
  @game_height 600

  describe "entity_hitbox/5" do
    test "returns a polygon for an angular entity" do
      hitbox = Hitbox.entity_hitbox(50.0, 33.3, 100, 100, @game_width, @game_height, :angular)

      assert %Polygons.Polygon{vertices: vertices} = hitbox
      # Angular has 6 points (diamond shape)
      assert length(vertices) == 6
    end

    test "returns a polygon for a node entity" do
      hitbox = Hitbox.entity_hitbox(50.0, 33.3, 100, 100, @game_width, @game_height, :node)

      assert %Polygons.Polygon{vertices: vertices} = hitbox
      assert length(vertices) == 6
    end

    test "returns a polygon for a ruby_rails entity" do
      hitbox = Hitbox.entity_hitbox(50.0, 33.3, 397, 142, @game_width, @game_height, :ruby_rails)

      assert %Polygons.Polygon{vertices: vertices} = hitbox
      assert length(vertices) == 5
    end

    test "returns a rectangle polygon for unknown sprite" do
      hitbox = Hitbox.entity_hitbox(50.0, 33.3, 50, 50, @game_width, @game_height, :unknown)

      assert %Polygons.Polygon{vertices: vertices} = hitbox
      assert length(vertices) == 4
    end
  end

  describe "player_hitbox/6" do
    test "returns a 6-point polygon for the player" do
      hitbox = Hitbox.player_hitbox(12.5, 50.0, 128, 89, @game_width, @game_height)

      assert %Polygons.Polygon{vertices: vertices} = hitbox
      assert length(vertices) == 6
    end
  end

  describe "collision detection with cached hitboxes" do
    test "detect_multiple_hits uses cached hitbox instead of recomputing from position" do
      # Entity's position says it's far away (90%, 90%), but its cached hitbox
      # is at the same spot as the player. If detection uses the cache,
      # it will detect a collision. If it recomputes from position, it won't.
      player_hitbox = Hitbox.player_hitbox(12.5, 16.66, 50, 50, @game_width, @game_height)
      overlapping_hitbox = Hitbox.entity_hitbox(12.5, 16.66, 100, 100, @game_width, @game_height, :angular)

      state = %{
        game_width: @game_width,
        game_height: @game_height,
        player: %{
          sprite: %{size: {50, 50}},
          position: {100.0, 100.0, 12.5, 16.66},
          hitbox: player_hitbox
        },
        enemies: [
          %{
            # Position says far away, but hitbox is overlapping player
            position: {700.0, 500.0, 90.0, 90.0},
            sprite: %{size: {100, 100}, name: :angular},
            hitbox: overlapping_hitbox
          }
        ]
      }

      result = Hitbox.check_for_enemy_collisions?(state)
      assert length(result) > 0, "should detect collision via cached hitbox, not recomputed from position"
    end
  end

  describe "hitbox caching in entity updates" do
    test "Enemy.update_enemies attaches hitbox to each enemy" do
      enemy = %Flappy.Enemy{
        position: {400.0, 200.0, 50.0, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-1"
      }

      state = %Flappy.FlappyEngine{
        game_id: "test",
        game_height: @game_height,
        game_width: @game_width,
        zoom_level: 1,
        gravity: 175,
        game_tick_interval: 15,
        score_tick_interval: 1000,
        score_multiplier: 10,
        difficulty_score: 400,
        game_over: false,
        player: %{
          score: 0,
          position: {100.0, 300.0, 12.5, 50.0},
          velocity: {0, 0},
          sprite: %{image: "/images/phoenix.svg", size: {50, 50}, name: :phoenix},
          granted_powers: [],
          laser_allowed: false,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false
        },
        enemies: [enemy],
        power_ups: [],
        explosions: []
      }

      new_state = Flappy.Enemy.update_enemies(state)

      [updated_enemy] = new_state.enemies
      assert %Polygons.Polygon{} = updated_enemy.hitbox
    end

    test "PowerUp.update_power_ups attaches hitbox to each power-up" do
      power_up = %Flappy.PowerUp{
        position: {200.0, 50.0, 25.0, 8.3},
        velocity: {0, 120},
        sprite: %{image: "/images/react.svg", size: {50, 50}, name: :invincibility, chance: 50, duration: 10},
        id: "pu-1"
      }

      state = %Flappy.FlappyEngine{
        game_id: "test",
        game_height: @game_height,
        game_width: @game_width,
        zoom_level: 1,
        gravity: 175,
        game_tick_interval: 15,
        score_tick_interval: 1000,
        score_multiplier: 10,
        difficulty_score: 400,
        game_over: false,
        player: %{
          score: 0,
          position: {100.0, 300.0, 12.5, 50.0},
          velocity: {0, 0},
          sprite: %{image: "/images/phoenix.svg", size: {50, 50}, name: :phoenix},
          granted_powers: [],
          laser_allowed: false,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false
        },
        enemies: [],
        power_ups: [power_up],
        explosions: []
      }

      new_state = Flappy.PowerUp.update_power_ups(state)

      updated_pu = Enum.find(new_state.power_ups, &(&1.id == "pu-1"))
      assert updated_pu, "power-up should still be present"
      assert %Polygons.Polygon{} = updated_pu.hitbox
    end

    test "Player.update_player attaches hitbox to player" do
      state = %Flappy.FlappyEngine{
        game_id: "test",
        game_height: @game_height,
        game_width: @game_width,
        zoom_level: 1,
        gravity: 175,
        game_tick_interval: 15,
        score_tick_interval: 1000,
        score_multiplier: 10,
        difficulty_score: 400,
        game_over: false,
        player: %{
          score: 0,
          position: {100.0, 300.0, 12.5, 50.0},
          velocity: {0.0, 0.0},
          sprite: %{image: "/images/phoenix.svg", size: {50, 50}, name: :phoenix},
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

      new_state = Flappy.Players.Player.update_player(state)

      assert %Polygons.Polygon{} = new_state.player.hitbox
    end
  end
end
