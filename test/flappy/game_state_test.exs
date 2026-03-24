defmodule Flappy.GameStateTest do
  use ExUnit.Case, async: true

  alias Flappy.GameState

  @player_id "test-player"

  describe "new/0" do
    test "creates a valid default game state struct" do
      state = GameState.new()

      assert %GameState{} = state
      assert state.game_over == false
      assert state.enemies == []
      assert state.power_ups == []
      assert state.explosions == []
      assert map_size(state.players) == 1
      player = first_player(state)
      assert player.position != nil
      assert player.velocity == {0.0, 0.0}
      assert state.gravity > 0
      assert state.game_height > 0
      assert state.game_width > 0
    end

    test "accepts top-level overrides" do
      state = GameState.new(gravity: 50, game_height: 1200)

      assert state.gravity == 50
      assert state.game_height == 1200
    end

    test "accepts player overrides merged into defaults" do
      state = GameState.new(player: %{laser_allowed: true, score: 42})

      player = first_player(state)
      assert player.laser_allowed == true
      assert player.score == 42
      # defaults preserved
      assert player.velocity == {0.0, 0.0}
      assert player.invincibility == false
    end
  end

  describe "handle_input/3" do
    test "go_up decreases y velocity (thrust upward)" do
      state = GameState.new(player_id: @player_id)
      {_vx, initial_vy} = first_player(state).velocity

      new_state = GameState.handle_input(state, @player_id, :go_up)

      {_vx, new_vy} = first_player(new_state).velocity
      assert new_vy < initial_vy, "y velocity should decrease (move up)"
    end

    test "go_down increases y velocity (thrust downward)" do
      state = GameState.new(player_id: @player_id)
      {_vx, initial_vy} = first_player(state).velocity

      new_state = GameState.handle_input(state, @player_id, :go_down)

      {_vx, new_vy} = first_player(new_state).velocity
      assert new_vy > initial_vy, "y velocity should increase (move down)"
    end

    test "go_right increases x velocity" do
      state = GameState.new(player_id: @player_id)
      {initial_vx, _vy} = first_player(state).velocity

      new_state = GameState.handle_input(state, @player_id, :go_right)

      {new_vx, _vy} = first_player(new_state).velocity
      assert new_vx > initial_vx, "x velocity should increase (move right)"
    end

    test "go_left decreases x velocity" do
      state = GameState.new(player_id: @player_id)
      {initial_vx, _vy} = first_player(state).velocity

      new_state = GameState.handle_input(state, @player_id, :go_left)

      {new_vx, _vy} = first_player(new_state).velocity
      assert new_vx < initial_vx, "x velocity should decrease (move left)"
    end

    test "fire_laser activates laser when laser_allowed" do
      state = GameState.new(player_id: @player_id, player: %{laser_allowed: true})

      new_state = GameState.handle_input(state, @player_id, :fire_laser)

      player = first_player(new_state)
      assert player.laser_beam == true
      assert player.laser_duration == 3
    end

    test "fire_laser is a no-op when laser not allowed" do
      state = GameState.new(player_id: @player_id, player: %{laser_allowed: false})

      new_state = GameState.handle_input(state, @player_id, :fire_laser)

      player = first_player(new_state)
      assert player.laser_beam == false
      assert player.laser_duration == 0
    end

    test "update_viewport changes dimensions and zoom" do
      state = GameState.new(player_id: @player_id)

      new_state = GameState.handle_input(state, @player_id, {:update_viewport, 2.0, 1920, 1080})

      assert new_state.zoom_level == 2.0
      assert new_state.game_width == 1920
      assert new_state.game_height == 1080
    end
  end

  defp base_state do
    %Flappy.GameState{
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
      players: %{
        @player_id => %{
          position: {100.0, 300.0, 12.5, 50.0},
          velocity: {0.0, 0.0},
          sprite: %{image: "/images/phoenix.svg", size: {50, 50}, name: :phoenix},
          score: 0,
          granted_powers: [],
          laser_allowed: false,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false,
          hitbox: nil,
          alive: true,
          name: "Test",
          survival_time: 0
        }
      },
      enemies: [],
      power_ups: [],
      explosions: [],
      deaths_this_tick: []
    }
  end

  defp first_player(%{players: players}) do
    {_id, player} = Enum.at(players, 0)
    player
  end

  describe "tick/1 player physics" do
    test "applies gravity to player velocity" do
      state = base_state()
      {:ok, new_state} = GameState.tick(state)

      {_x_vel, y_vel} = first_player(new_state).velocity
      # gravity=175, tick=15ms -> delta = 175 * 0.015 = 2.625
      assert y_vel > 0, "gravity should increase y velocity downward"
    end

    test "updates player position based on velocity" do
      state = base_state()
      player = %{state.players[@player_id] | velocity: {10.0, 20.0}}
      state = %{state | players: %{@player_id => player}}

      {:ok, new_state} = GameState.tick(state)

      {new_x, new_y, _xp, _yp} = first_player(new_state).position
      {orig_x, orig_y, _xp, _yp} = player.position

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

      updated_enemy = Enum.find(new_state.enemies, &(&1.id == "enemy-1"))
      assert updated_enemy, "original enemy should still be present"
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

      # off-screen enemy should be removed, regardless of any newly spawned enemies
      refute Enum.any?(new_state.enemies, &(&1.id == "enemy-offscreen"))
      # original on-screen enemy should still be present
      assert Enum.any?(new_state.enemies, &(&1.id == "enemy-onscreen"))
    end
  end

  describe "tick/1 explosions" do
    test "decrements explosion duration and removes expired ones" do
      state = base_state()

      active = %Flappy.Explosion{
        duration: 2,
        position: {100.0, 100.0, 12.5, 16.6},
        velocity: {-50, 0},
        sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
        id: "exp-1"
      }

      expiring = %Flappy.Explosion{
        duration: 1,
        position: {200.0, 200.0, 25.0, 33.3},
        velocity: {-50, 0},
        sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
        id: "exp-2"
      }

      expired = %Flappy.Explosion{
        duration: 0,
        position: {300.0, 300.0, 37.5, 50.0},
        velocity: {-50, 0},
        sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
        id: "exp-3"
      }

      state = %{state | explosions: [active, expiring, expired]}

      {:ok, new_state} = GameState.tick(state)

      # expired (duration 0) is removed; expiring (1) decremented to 0 but kept; active (2) decremented to 1
      assert length(new_state.explosions) == 2
      durations = new_state.explosions |> Enum.map(& &1.duration) |> Enum.sort()
      assert 0 in durations
      assert 1 in durations
    end
  end

  describe "tick/1 collision detection" do
    test "returns game_over when player collides with enemy (no invincibility)" do
      state = base_state()
      # Place enemy right on top of player
      {px, py, pxp, pyp} = state.players[@player_id].position

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
      {px, py, pxp, pyp} = state.players[@player_id].position

      enemy = %Flappy.Enemy{
        position: {px, py, pxp, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {50, 50}, name: :angular},
        id: "enemy-collide"
      }

      player = %{state.players[@player_id] | invincibility: true, granted_powers: [{:invincibility, 5}]}
      state = %{state | enemies: [enemy], players: %{@player_id => player}}

      assert {:ok, new_state} = GameState.tick(state)
      assert new_state.game_over == false
      # Original enemy should be destroyed; new enemies may spawn during tick
      refute Enum.any?(new_state.enemies, &(&1.id == "enemy-collide"))
      assert length(new_state.explosions) > 0
    end
  end

  describe "tick/1 out of bounds" do
    test "game over when player goes above screen" do
      state = base_state()
      player = %{state.players[@player_id] | position: {100.0, -50.0, 12.5, -8.3}}
      state = %{state | players: %{@player_id => player}}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end

    test "game over when player falls below screen" do
      state = base_state()
      # y% > 100 - sprite_height_percent
      player = %{state.players[@player_id] | position: {100.0, 590.0, 12.5, 98.0}}
      state = %{state | players: %{@player_id => player}}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end

    test "game over when player goes off right side" do
      state = base_state()
      player = %{state.players[@player_id] | position: {850.0, 300.0, 106.0, 50.0}}
      state = %{state | players: %{@player_id => player}}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end

    test "game over when player goes off left side" do
      state = base_state()
      # After tick, sprite may be resized by grant_power_ups (128px wide).
      # Threshold: 0 - 128/800*100 = -16%. Use x% well below that.
      player = %{state.players[@player_id] | position: {-200.0, 300.0, -25.0, 50.0}}
      state = %{state | players: %{@player_id => player}}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end
  end

  describe "tick/1 laser" do
    test "laser beam destroys enemies in its path" do
      state = base_state()
      # Player at left side, enemy to the right at same y-level
      player = %{
        state.players[@player_id]
        | laser_beam: true,
          laser_duration: 3,
          laser_allowed: true,
          invincibility: true,
          granted_powers: [{:invincibility, 5}]
      }

      # Enemy at same y as player but to the right
      {_px, py, _pxp, pyp} = player.position

      enemy = %Flappy.Enemy{
        position: {500.0, py, 62.5, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-laser-target"
      }

      state = %{state | players: %{@player_id => player}, enemies: [enemy]}

      {:ok, new_state} = GameState.tick(state)

      # Target enemy should be destroyed by laser; new enemies may spawn during tick
      refute Enum.any?(new_state.enemies, &(&1.id == "enemy-laser-target"))
      assert length(new_state.explosions) > 0
    end
  end

  describe "tick/1 power-up collection" do
    test "player collects power-up on contact and gains its effect" do
      state = base_state()
      {px, py, pxp, pyp} = state.players[@player_id].position

      power_up = %Flappy.PowerUp{
        position: {px, py, pxp, pyp},
        velocity: {0, 100},
        sprite: %{image: "/images/react.svg", size: {50, 50}, name: :invincibility, chance: 50, duration: 10},
        id: "powerup-1"
      }

      state = %{state | power_ups: [power_up]}

      {:ok, new_state} = GameState.tick(state)

      player = first_player(new_state)
      refute Enum.any?(new_state.power_ups, &(&1.id == "powerup-1"))
      assert player.invincibility == true
      assert {:invincibility, _duration} = List.keyfind(player.granted_powers, :invincibility, 0)
    end

    test "bomb power-up destroys all enemies and creates explosion" do
      state = base_state()
      {px, py, pxp, pyp} = state.players[@player_id].position

      # Place bomb power-up on the player
      bomb = %Flappy.PowerUp{
        position: {px, py, pxp, pyp},
        velocity: {0, 100},
        sprite: %{image: "/images/bomb.svg", size: {50, 50}, name: :bomb, chance: 20, duration: 0},
        id: "bomb-1"
      }

      # Place some enemies on screen
      enemy1 = %Flappy.Enemy{
        position: {400.0, 200.0, 50.0, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-1"
      }

      enemy2 = %Flappy.Enemy{
        position: {600.0, 100.0, 75.0, 16.6},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/node.svg", size: {100, 100}, name: :node},
        id: "enemy-2"
      }

      state = %{state | power_ups: [bomb], enemies: [enemy1, enemy2]}

      {:ok, new_state} = GameState.tick(state)

      # Bomb should destroy the original enemies; new enemies may spawn during tick
      refute Enum.any?(new_state.enemies, &(&1.id == "enemy-1"))
      refute Enum.any?(new_state.enemies, &(&1.id == "enemy-2"))
      # Should have explosion from the bomb
      assert length(new_state.explosions) > 0
      # Score should increase by enemies_killed * score_multiplier
      assert first_player(new_state).score >= 2 * state.score_multiplier
    end
  end

  describe "score_tick/1" do
    test "increments player score by 1" do
      state = base_state()
      new_state = GameState.score_tick(state)

      assert first_player(new_state).score == 1
    end

    test "decrements power-up durations and removes expired ones" do
      state = base_state()
      player = %{state.players[@player_id] | granted_powers: [{:laser, 2}, {:invincibility, 0}]}
      state = %{state | players: %{@player_id => player}}

      new_state = GameState.score_tick(state)

      # laser: 2->1 (kept), invincibility: 0->nil (removed)
      assert first_player(new_state).granted_powers == [{:laser, 1}]
    end

    test "may generate enemies on even score ticks" do
      state = base_state()
      # Score will become 1 (odd) — no enemy generation
      player = %{state.players[@player_id] | score: 0}
      state = %{state | players: %{@player_id => player}}

      new_state = GameState.score_tick(state)
      # Score is now 1 (odd), so no enemy generation triggered
      assert first_player(new_state).score == 1
      assert new_state.enemies == []
    end

    test "triggers enemy generation check on even score" do
      state = base_state()
      # Score will become 2 (even) — enemy generation attempted
      player = %{state.players[@player_id] | score: 1}
      # Set difficulty_score very low so generation is very likely
      state = %{state | players: %{@player_id => player}, difficulty_score: 6}

      # Run many times to statistically verify generation happens
      results =
        for _ <- 1..100 do
          new_state = GameState.score_tick(state)
          length(new_state.enemies)
        end

      # At least some runs should have generated an enemy
      assert Enum.any?(results, &(&1 > 0)), "enemies should be generated on even score ticks"
    end

    test "generates power-ups on score divisible by 10" do
      state = base_state()
      player = %{state.players[@player_id] | score: 9}
      state = %{state | players: %{@player_id => player}}

      new_state = GameState.score_tick(state)

      assert first_player(new_state).score == 10
      assert length(new_state.power_ups) == 1
    end
  end
end
