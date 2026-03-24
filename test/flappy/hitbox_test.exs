defmodule Flappy.HitboxTest do
  use ExUnit.Case

  alias Flappy.Hitbox

  describe "get_hit_enemies/2" do
    test "detects collision with enemy" do
      game_state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {0, 0, 100, 100}
        }
      }

      enemy = %{
        position: {0, 0, 100, 100},
        sprite: %{size: {50, 50}, name: :angular}
      }

      result = Hitbox.get_hit_enemies([enemy], game_state)
      assert length(result) > 0
    end

    test "returns empty list when no collisions" do
      game_state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {0, 0, 100, 100}
        }
      }

      enemy = %{
        # Far away position
        position: {0, 0, 500, 500},
        sprite: %{size: {50, 50}, name: :angular}
      }

      result = Hitbox.get_hit_enemies([enemy], game_state)
      assert result == []
    end
  end

  describe "get_hit_power_ups/2" do
    test "detects collision with power up" do
      state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {0, 0, 100, 100}
        }
      }

      power_up = %{
        position: {0, 0, 100, 100},
        sprite: %{size: {30, 30}, name: :node}
      }

      result = Hitbox.get_hit_power_ups([power_up], state)
      assert length(result) > 0
    end
  end

  describe "get_hit_enemies/2 laser" do
    test "laser hits enemy in its path" do
      # Player at x=12.5%, y=50% on 800×600
      game_state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {100.0, 300.0, 12.5, 50.0}
        }
      }

      # Enemy placed ahead of the laser beam at ~30% x, same y height
      enemy = %{
        position: {240.0, 300.0, 30.0, 50.0},
        sprite: %{size: {100, 100}, name: :angular}
      }

      result = Hitbox.get_hit_enemies([enemy], game_state)
      assert length(result) > 0
    end

    test "laser does not hit enemy far above the beam" do
      game_state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {100.0, 300.0, 12.5, 50.0}
        }
      }

      # Enemy far above the laser beam
      enemy = %{
        position: {240.0, 30.0, 30.0, 5.0},
        sprite: %{size: {100, 100}, name: :angular}
      }

      result = Hitbox.get_hit_enemies([enemy], game_state)
      assert result == []
    end

    test "laser hitbox is a proper rectangle (not a trapezoid)" do
      # Regression: previously the bottom-left vertex used {w, y+h}
      # instead of {x, y+h}, creating a trapezoid
      game_state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {400.0, 300.0, 50.0, 50.0}
        }
      }

      # Enemy behind the player (x=5%) should NOT be hit by a laser
      # that starts at the bird's eye (~x=55%). With the old bug,
      # the trapezoid stretched back to x=100px and could false-positive.
      enemy = %{
        position: {40.0, 300.0, 5.0, 50.0},
        sprite: %{size: {100, 100}, name: :angular}
      }

      result = Hitbox.get_hit_enemies([enemy], game_state)
      assert result == [], "laser should not hit enemies behind the player"
    end
  end

  describe "check_for_enemy_collisions?/1" do
    test "detects player collision with enemy" do
      state = %{
        game_width: 800,
        game_height: 600,
        player: %{
          sprite: %{size: {50, 50}},
          position: {0, 0, 100, 100}
        },
        enemies: [
          %{
            position: {0, 0, 100, 100},
            sprite: %{size: {50, 50}, name: :angular}
          }
        ]
      }

      result = Hitbox.check_for_enemy_collisions?(state)
      assert length(result) > 0
    end
  end
end
