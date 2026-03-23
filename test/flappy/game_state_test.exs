defmodule Flappy.GameStateTest do
  use ExUnit.Case, async: true

  alias Flappy.GameState

  defp base_state do
    %Flappy.FlappyEngine{
      game_id: "test-game",
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
        position: {100.0, 300.0, 12.5, 50.0},
        velocity: {0.0, 0.0},
        sprite: %{image: "/images/phoenix.svg", size: {50, 50}, name: :phoenix},
        score: 0,
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
  end

  describe "tick/1 player physics" do
    test "applies gravity to player velocity" do
      state = base_state()
      {:ok, new_state} = GameState.tick(state)

      {_x_vel, y_vel} = new_state.player.velocity
      # gravity=175, tick=15ms -> delta = 175 * 0.015 = 2.625
      assert y_vel > 0, "gravity should increase y velocity downward"
    end

    test "updates player position based on velocity" do
      state = base_state()
      player = %{state.player | velocity: {10.0, 20.0}}
      state = %{state | player: player}

      {:ok, new_state} = GameState.tick(state)

      {new_x, new_y, _xp, _yp} = new_state.player.position
      {orig_x, orig_y, _xp, _yp} = state.player.position

      assert new_x > orig_x, "player should move right with positive x velocity"
      assert new_y > orig_y, "player should move down with positive y velocity"
    end
  end

  describe "tick/1 enemy movement" do
    test "moves enemies leftward" do
      state = base_state()
      enemy = %Flappy.Enemy{
        position: {400.0, 200.0, 50.0, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-1"
      }
      state = %{state | enemies: [enemy]}

      {:ok, new_state} = GameState.tick(state)

      [updated_enemy] = new_state.enemies
      {new_x, _y, _xp, _yp} = updated_enemy.position
      assert new_x < 400.0, "enemy should move left"
    end

    test "removes enemies that are far off-screen left" do
      state = base_state()
      offscreen_enemy = %Flappy.Enemy{
        position: {-300.0, 200.0, -37.5, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-offscreen"
      }
      onscreen_enemy = %Flappy.Enemy{
        position: {400.0, 200.0, 50.0, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-onscreen"
      }
      state = %{state | enemies: [offscreen_enemy, onscreen_enemy]}

      {:ok, new_state} = GameState.tick(state)

      assert length(new_state.enemies) == 1
      assert hd(new_state.enemies).id == "enemy-onscreen"
    end
  end

  describe "tick/1 explosions" do
    test "decrements explosion duration and removes expired ones" do
      state = base_state()
      active = %Flappy.Explosion{duration: 2, position: {100.0, 100.0, 12.5, 16.6}, velocity: {-50, 0}, sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion}, id: "exp-1"}
      expiring = %Flappy.Explosion{duration: 1, position: {200.0, 200.0, 25.0, 33.3}, velocity: {-50, 0}, sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion}, id: "exp-2"}
      expired = %Flappy.Explosion{duration: 0, position: {300.0, 300.0, 37.5, 50.0}, velocity: {-50, 0}, sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion}, id: "exp-3"}
      state = %{state | explosions: [active, expiring, expired]}

      {:ok, new_state} = GameState.tick(state)

      # expired (0) should be removed, expiring (1) decremented to 0 and removed, active (2) decremented to 1
      assert length(new_state.explosions) == 2
      durations = Enum.map(new_state.explosions, & &1.duration) |> Enum.sort()
      assert 0 in durations
      assert 1 in durations
    end
  end

  describe "tick/1 collision detection" do
    test "returns game_over when player collides with enemy (no invincibility)" do
      state = base_state()
      # Place enemy right on top of player
      {px, py, pxp, pyp} = state.player.position
      enemy = %Flappy.Enemy{
        position: {px, py, pxp, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {50, 50}, name: :angular},
        id: "enemy-collide"
      }
      state = %{state | enemies: [enemy]}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end

    test "with invincibility, destroys enemies instead of game over" do
      state = base_state()
      {px, py, pxp, pyp} = state.player.position
      enemy = %Flappy.Enemy{
        position: {px, py, pxp, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {50, 50}, name: :angular},
        id: "enemy-collide"
      }
      player = %{state.player | invincibility: true, granted_powers: [{:invincibility, 5}]}
      state = %{state | enemies: [enemy], player: player}

      assert {:ok, new_state} = GameState.tick(state)
      assert new_state.game_over == false
      # Enemy should be destroyed (removed and turned into explosion)
      assert new_state.enemies == []
      assert length(new_state.explosions) > 0
    end
  end

  describe "tick/1 out of bounds" do
    test "game over when player goes above screen" do
      state = base_state()
      player = %{state.player | position: {100.0, -50.0, 12.5, -8.3}}
      state = %{state | player: player}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end

    test "game over when player falls below screen" do
      state = base_state()
      # y% > 100 - sprite_height_percent
      player = %{state.player | position: {100.0, 590.0, 12.5, 98.0}}
      state = %{state | player: player}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end

    test "game over when player goes off right side" do
      state = base_state()
      player = %{state.player | position: {850.0, 300.0, 106.0, 50.0}}
      state = %{state | player: player}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end
  end

  describe "tick/1 laser" do
    test "laser beam destroys enemies in its path" do
      state = base_state()
      # Player at left side, enemy to the right at same y-level
      player = %{state.player |
        laser_beam: true,
        laser_duration: 3,
        laser_allowed: true,
        invincibility: true,
        granted_powers: [{:invincibility, 5}]
      }
      # Enemy at same y as player but to the right
      {_px, py, _pxp, pyp} = state.player.position
      enemy = %Flappy.Enemy{
        position: {500.0, py, 62.5, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-laser-target"
      }
      state = %{state | player: player, enemies: [enemy]}

      {:ok, new_state} = GameState.tick(state)

      # Enemy should be destroyed by laser
      assert new_state.enemies == []
      assert length(new_state.explosions) > 0
    end
  end

  describe "tick/1 power-up collection" do
    test "player collects power-up on contact and gains its effect" do
      state = base_state()
      {px, py, pxp, pyp} = state.player.position
      power_up = %Flappy.PowerUp{
        position: {px, py, pxp, pyp},
        velocity: {0, 100},
        sprite: %{image: "/images/react.svg", size: {50, 50}, name: :invincibility, chance: 50, duration: 10},
        id: "powerup-1"
      }
      state = %{state | power_ups: [power_up]}

      {:ok, new_state} = GameState.tick(state)

      assert new_state.power_ups == []
      assert new_state.player.invincibility == true
      assert {:invincibility, _duration} = List.keyfind(new_state.player.granted_powers, :invincibility, 0)
    end
  end

  describe "score_tick/1" do
    test "increments player score by 1" do
      state = base_state()
      new_state = GameState.score_tick(state)

      assert new_state.player.score == 1
    end

    test "decrements power-up durations and removes expired ones" do
      state = base_state()
      player = %{state.player | granted_powers: [{:laser, 2}, {:invincibility, 0}]}
      state = %{state | player: player}

      new_state = GameState.score_tick(state)

      # laser: 2->1 (kept), invincibility: 0->nil (removed)
      assert new_state.player.granted_powers == [{:laser, 1}]
    end

    test "may generate enemies on even score ticks" do
      state = base_state()
      # Score will become 1 (odd) — no enemy generation
      player = %{state.player | score: 0}
      state = %{state | player: player}

      new_state = GameState.score_tick(state)
      # Score is now 1 (odd), so no enemy generation triggered
      assert new_state.player.score == 1
      assert new_state.enemies == []
    end

    test "triggers enemy generation check on even score" do
      state = base_state()
      # Score will become 2 (even) — enemy generation attempted
      player = %{state.player | score: 1}
      # Set difficulty_score very low so generation is very likely
      state = %{state | player: player, difficulty_score: 6}

      # Run many times to statistically verify generation happens
      results = for _ <- 1..100 do
        new_state = GameState.score_tick(state)
        length(new_state.enemies)
      end

      # At least some runs should have generated an enemy
      assert Enum.any?(results, &(&1 > 0)), "enemies should be generated on even score ticks"
    end

    test "generates power-ups on score divisible by 10" do
      state = base_state()
      player = %{state.player | score: 9}
      state = %{state | player: player}

      new_state = GameState.score_tick(state)

      assert new_state.player.score == 10
      assert length(new_state.power_ups) == 1
    end
  end
end
