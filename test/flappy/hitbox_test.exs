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
