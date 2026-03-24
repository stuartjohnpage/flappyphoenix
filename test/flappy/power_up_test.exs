defmodule Flappy.PowerUpTest do
  use ExUnit.Case, async: true

  alias Flappy.PowerUp

  describe "derive_power_flags/1" do
    test "laser power returns laser_allowed true with laser sprite" do
      granted_powers = [{:laser, 5}]
      flags = PowerUp.derive_power_flags(granted_powers)

      assert flags.laser_allowed == true
      assert flags.invincibility == false
      assert flags.sprite.name == :laser_phoenix
    end

    test "invincibility power returns invincibility true with invincible sprite" do
      granted_powers = [{:invincibility, 3}]
      flags = PowerUp.derive_power_flags(granted_powers)

      assert flags.laser_allowed == false
      assert flags.invincibility == true
      # invincible sprite
      assert flags.sprite.name == :laser_phoenix
    end

    test "both laser and invincibility returns both true with combined sprite" do
      granted_powers = [{:laser, 5}, {:invincibility, 3}]
      flags = PowerUp.derive_power_flags(granted_powers)

      assert flags.laser_allowed == true
      assert flags.invincibility == true
      assert flags.sprite == Flappy.Players.get_sprite(:laser_invincibility)
    end

    test "empty granted_powers returns both false with default sprite" do
      flags = PowerUp.derive_power_flags([])

      assert flags.laser_allowed == false
      assert flags.invincibility == false
      assert flags.sprite == Flappy.Players.get_sprite()
    end

    test "bomb (duration 0) does not reset other active power flags" do
      # Player has laser active, then picks up bomb — laser should persist
      granted_powers = [{:laser, 5}, {:bomb, 0}]
      flags = PowerUp.derive_power_flags(granted_powers)

      assert flags.laser_allowed == true, "bomb should not reset laser flag"
      assert flags.invincibility == false
    end

    test "expired powers (duration 0) are not considered active" do
      granted_powers = [{:laser, 0}, {:invincibility, 0}]
      flags = PowerUp.derive_power_flags(granted_powers)

      assert flags.laser_allowed == false
      assert flags.invincibility == false
      assert flags.sprite == Flappy.Players.get_sprite()
    end
  end

  describe "grant_power_ups/2 integration" do
    test "collecting bomb while laser is active doesn't reset laser" do
      bomb = %Flappy.PowerUp{
        position: {200.0, 300.0, 25.0, 50.0},
        velocity: {0, 100},
        sprite: %{image: "/images/bomb.svg", size: {50, 50}, name: :bomb, chance: 20, duration: 0},
        id: "bomb-1"
      }

      state = %{
        player: %{
          score: 10,
          granted_powers: [{:laser, 5}],
          laser_allowed: true,
          invincibility: false,
          sprite: Flappy.Players.get_sprite(:laser),
          position: {100.0, 300.0, 12.5, 50.0},
          velocity: {0, 0},
          laser_beam: false,
          laser_duration: 0
        },
        power_ups: [bomb],
        enemies: [
          %Flappy.Enemy{
            position: {400.0, 200.0, 50.0, 33.3},
            velocity: {-75.0, 0},
            sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
            id: "enemy-1",
            hitbox: nil
          }
        ],
        explosions: [],
        score_multiplier: 10
      }

      new_state = Flappy.PowerUp.grant_power_ups(state, [bomb])

      assert new_state.player.laser_allowed == true, "laser should still be active after bomb"
      assert new_state.player.sprite == Flappy.Players.get_sprite(:laser)
    end
  end

  describe "score_tick power expiry" do
    test "player loses laser_allowed and sprite reverts when laser expires" do
      state = %Flappy.FlappyEngine{
        game_id: "test",
        game_height: 600,
        game_width: 800,
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
          sprite: Flappy.Players.get_sprite(:laser),
          granted_powers: [{:laser, 1}],
          laser_allowed: true,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false
        },
        enemies: [],
        power_ups: [],
        explosions: []
      }

      # After score_tick, laser duration goes 1->0, then gets removed
      # Player should lose laser_allowed and revert to default sprite
      new_state = Flappy.GameState.score_tick(state)

      # Duration 1->0 means it's still in the list but at 0
      # Next tick it'll be removed. But flags should update based on current state.
      # With duration 0, laser is effectively expired.
      assert new_state.player.laser_allowed == false,
             "laser_allowed should be false when laser power expires"

      assert new_state.player.sprite == Flappy.Players.get_sprite(),
             "sprite should revert to default when laser expires"
    end
  end

  describe "score_for_kills/2" do
    test "calculates score as kill_count * multiplier" do
      assert PowerUp.score_for_kills(5, 10) == 50
      assert PowerUp.score_for_kills(0, 10) == 0
      assert PowerUp.score_for_kills(3, 15) == 45
    end
  end
end
