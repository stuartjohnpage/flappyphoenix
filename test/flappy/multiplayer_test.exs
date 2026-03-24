defmodule Flappy.MultiplayerTest do
  use ExUnit.Case, async: true

  alias Flappy.GameState

  @player_a "player-a"
  @player_b "player-b"

  defp base_multiplayer_state do
    state = %GameState{
      game_id: "test-mp",
      game_height: 600,
      game_width: 800,
      zoom_level: 1,
      gravity: 175,
      game_tick_interval: 15,
      score_tick_interval: 1000,
      score_multiplier: 10,
      difficulty_score: 400,
      game_over: false,
      players: %{},
      enemies: [],
      power_ups: [],
      explosions: [],
      deaths_this_tick: []
    }

    state
    |> GameState.add_player(@player_a, "Alice")
    |> GameState.add_player(@player_b, "Bob")
  end

  describe "add_player/3" do
    test "adds a player to the players map" do
      state = %GameState{
        game_id: "test",
        game_height: 600,
        game_width: 800,
        players: %{},
        deaths_this_tick: []
      }

      state = GameState.add_player(state, "p1", "Alice")

      assert map_size(state.players) == 1
      assert state.players["p1"].name == "Alice"
      assert state.players["p1"].alive == true
      assert state.players["p1"].survival_time == 0
    end
  end

  describe "remove_player/2" do
    test "removes a player and creates explosion if alive" do
      state = base_multiplayer_state()

      state = GameState.remove_player(state, @player_a)

      assert map_size(state.players) == 1
      refute Map.has_key?(state.players, @player_a)
      assert length(state.explosions) == 1
    end

    test "removes a dead player without creating explosion" do
      state = base_multiplayer_state()
      player = %{state.players[@player_a] | alive: false}
      state = %{state | players: Map.put(state.players, @player_a, player)}

      state = GameState.remove_player(state, @player_a)

      assert map_size(state.players) == 1
      assert state.explosions == []
    end
  end

  describe "multi-player tick" do
    test "both players move independently" do
      state = base_multiplayer_state()
      {:ok, new_state} = GameState.tick(state)

      a = new_state.players[@player_a]
      b = new_state.players[@player_b]

      # Both should have been affected by gravity
      {_, ya_vel} = a.velocity
      {_, yb_vel} = b.velocity
      assert ya_vel > 0
      assert yb_vel > 0
    end

    test "dead player is not updated" do
      state = base_multiplayer_state()
      player_a = %{state.players[@player_a] | alive: false, velocity: {0.0, 0.0}}
      state = %{state | players: Map.put(state.players, @player_a, player_a)}

      {:ok, new_state} = GameState.tick(state)

      # Dead player velocity should be unchanged
      assert new_state.players[@player_a].velocity == {0.0, 0.0}
      # Alive player should have been updated
      {_, yb_vel} = new_state.players[@player_b].velocity
      assert yb_vel > 0
    end
  end

  describe "per-player collision" do
    test "player A dies from collision, player B unaffected" do
      state = base_multiplayer_state()

      # Place an enemy on top of player A
      {px, py, pxp, pyp} = state.players[@player_a].position

      enemy = %Flappy.Enemy{
        position: {px, py, pxp, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {50, 50}, name: :angular},
        id: "enemy-1"
      }

      state = %{state | enemies: [enemy]}

      {:ok, new_state} = GameState.tick(state)

      # Player A should be dead
      refute new_state.players[@player_a].alive
      # Player B should be alive
      assert new_state.players[@player_b].alive
      # Game should NOT be over (one player still alive)
      assert new_state.game_over == false
      # Player A should be in deaths_this_tick
      assert @player_a in new_state.deaths_this_tick
    end

    test "game over when both players die" do
      state = base_multiplayer_state()

      # Place players at different positions, each with their own enemy
      pos_a = {100.0, 300.0, 12.5, 50.0}
      pos_b = {400.0, 200.0, 50.0, 33.3}
      player_a = %{state.players[@player_a] | position: pos_a}
      player_b = %{state.players[@player_b] | position: pos_b}
      state = %{state | players: %{@player_a => player_a, @player_b => player_b}}

      enemy_a = %Flappy.Enemy{
        position: pos_a,
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {50, 50}, name: :angular},
        id: "enemy-a"
      }

      enemy_b = %Flappy.Enemy{
        position: pos_b,
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {50, 50}, name: :angular},
        id: "enemy-b"
      }

      state = %{state | enemies: [enemy_a, enemy_b]}

      assert {:game_over, new_state} = GameState.tick(state)
      assert new_state.game_over == true
    end
  end

  describe "power-up collection" do
    test "first player to touch power-up gets it" do
      state = base_multiplayer_state()

      # Place both players at same position near a power-up
      pos = {100.0, 300.0, 12.5, 50.0}
      player_a = %{state.players[@player_a] | position: pos}
      player_b = %{state.players[@player_b] | position: pos}
      state = %{state | players: %{@player_a => player_a, @player_b => player_b}}

      power_up = %Flappy.PowerUp{
        position: {100.0, 300.0, 12.5, 50.0},
        velocity: {0, 100},
        sprite: %{image: "/images/react.svg", size: {50, 50}, name: :invincibility, chance: 50, duration: 10},
        id: "pu-1"
      }

      state = %{state | power_ups: [power_up]}

      {:ok, new_state} = GameState.tick(state)

      # Power-up should be gone
      refute Enum.any?(new_state.power_ups, &(&1.id == "pu-1"))

      # Exactly one player should have gained invincibility
      a_inv = new_state.players[@player_a].invincibility
      b_inv = new_state.players[@player_b].invincibility

      assert (a_inv and not b_inv) or (not a_inv and b_inv),
             "exactly one player should get the power-up"
    end
  end

  describe "shared enemy kills" do
    test "laser kill removes enemy for everyone" do
      state = base_multiplayer_state()

      # Give player A a laser
      player_a = %{
        state.players[@player_a]
        | laser_beam: true,
          laser_duration: 3,
          laser_allowed: true,
          invincibility: true,
          granted_powers: [{:invincibility, 5}]
      }

      state = %{state | players: Map.put(state.players, @player_a, player_a)}

      {_px, py, _pxp, pyp} = player_a.position

      enemy = %Flappy.Enemy{
        position: {500.0, py, 62.5, pyp},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "enemy-laser"
      }

      state = %{state | enemies: [enemy]}

      {:ok, new_state} = GameState.tick(state)

      # Enemy destroyed by player A's laser - gone for everyone
      refute Enum.any?(new_state.enemies, &(&1.id == "enemy-laser"))
      # Score goes to player A
      assert new_state.players[@player_a].score > 0
    end
  end

  describe "crown computation" do
    test "crown belongs to longest-surviving player" do
      state = base_multiplayer_state()

      # Give player A more survival time
      player_a = %{state.players[@player_a] | survival_time: 10}
      player_b = %{state.players[@player_b] | survival_time: 5}
      state = %{state | players: %{@player_a => player_a, @player_b => player_b}}

      assert GameState.crown_holder(state) == @player_a
    end

    test "crown transfers when holder dies" do
      state = base_multiplayer_state()

      player_a = %{state.players[@player_a] | survival_time: 10, alive: false}
      player_b = %{state.players[@player_b] | survival_time: 5}
      state = %{state | players: %{@player_a => player_a, @player_b => player_b}}

      assert GameState.crown_holder(state) == @player_b
    end

    test "crown is nil when no players alive" do
      state = base_multiplayer_state()

      player_a = %{state.players[@player_a] | alive: false}
      player_b = %{state.players[@player_b] | alive: false}
      state = %{state | players: %{@player_a => player_a, @player_b => player_b}}

      assert GameState.crown_holder(state) == nil
    end
  end

  describe "last bird standing" do
    test "detected when one player alive and at least one dead" do
      state = base_multiplayer_state()

      player_a = %{state.players[@player_a] | alive: false}
      state = %{state | players: Map.put(state.players, @player_a, player_a)}

      assert GameState.last_bird_standing?(state)
    end

    test "not triggered with only one player total" do
      state = base_multiplayer_state()
      state = %{state | players: Map.delete(state.players, @player_b)}

      refute GameState.last_bird_standing?(state)
    end

    test "not triggered when all alive" do
      state = base_multiplayer_state()

      refute GameState.last_bird_standing?(state)
    end
  end

  describe "survival time" do
    test "increments each score tick for alive players" do
      state = base_multiplayer_state()

      new_state = GameState.score_tick(state)

      assert new_state.players[@player_a].survival_time == 1
      assert new_state.players[@player_b].survival_time == 1
    end

    test "does not increment for dead players" do
      state = base_multiplayer_state()

      player_a = %{state.players[@player_a] | alive: false, survival_time: 5}
      state = %{state | players: Map.put(state.players, @player_a, player_a)}

      new_state = GameState.score_tick(state)

      assert new_state.players[@player_a].survival_time == 5
      assert new_state.players[@player_b].survival_time == 1
    end
  end

  describe "input routing" do
    test "handle_input only affects specified player" do
      state = base_multiplayer_state()

      new_state = GameState.handle_input(state, @player_a, :go_up)

      {_, a_vy} = new_state.players[@player_a].velocity
      {_, b_vy} = new_state.players[@player_b].velocity

      assert a_vy < 0, "player A should have upward velocity"
      assert b_vy == 0.0, "player B should be unaffected"
    end

    test "input to dead player is ignored" do
      state = base_multiplayer_state()
      player_a = %{state.players[@player_a] | alive: false}
      state = %{state | players: Map.put(state.players, @player_a, player_a)}

      new_state = GameState.handle_input(state, @player_a, :go_up)

      assert new_state.players[@player_a].velocity == {0.0, 0.0}
    end
  end

  describe "no player-player collisions" do
    test "overlapping players don't affect each other" do
      state = base_multiplayer_state()

      # Place both players at exact same position
      pos = {200.0, 200.0, 25.0, 33.3}
      player_a = %{state.players[@player_a] | position: pos}
      player_b = %{state.players[@player_b] | position: pos}
      state = %{state | players: %{@player_a => player_a, @player_b => player_b}}

      {:ok, new_state} = GameState.tick(state)

      # Both should still be alive
      assert new_state.players[@player_a].alive
      assert new_state.players[@player_b].alive
    end
  end

  describe "alive_count" do
    test "counts alive players" do
      state = base_multiplayer_state()
      assert GameState.alive_count(state) == 2

      player_a = %{state.players[@player_a] | alive: false}
      state = %{state | players: Map.put(state.players, @player_a, player_a)}
      assert GameState.alive_count(state) == 1
    end
  end

  describe "server reset on empty" do
    test "removing last player results in empty players map" do
      state = base_multiplayer_state()

      state =
        state
        |> GameState.remove_player(@player_a)
        |> GameState.remove_player(@player_b)

      assert map_size(state.players) == 0
    end
  end

  describe "explosion positioning" do
    test "explosion is centered on enemy when enemy is destroyed" do
      # Use remove_hit_enemies directly to test centering logic in isolation
      state = %{
        game_width: 800,
        game_height: 600,
        score_multiplier: 10,
        enemies: [],
        explosions: [],
        players: %{
          "p1" => %{
            score: 0,
            alive: true
          }
        }
      }

      # ruby_rails is 397x142 — a wide enemy where centering matters
      enemy = %Flappy.Enemy{
        position: {300.0, 200.0, 37.5, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/ruby_rails.svg", size: {397, 142}, name: :ruby_rails},
        id: "wide-enemy"
      }

      state = %{state | enemies: [enemy]}
      new_state = Flappy.Enemy.remove_hit_enemies(state, [enemy], "p1")

      assert length(new_state.explosions) == 1

      [explosion] = new_state.explosions
      {_, _, exp_x, exp_y} = explosion.position
      {_, _, enemy_x, enemy_y} = enemy.position

      # Explosion should be offset from enemy origin (centered on enemy)
      # For ruby_rails: 397x142, explosion: 100x100
      # x_offset = (397 - 100) / 2 / 800 * 100 = 18.5625
      # y_offset = (142 - 100) / 2 / 600 * 100 = 3.5
      assert exp_x > enemy_x, "explosion x should be offset right to center on wide enemy"
      assert exp_y > enemy_y, "explosion y should be offset down to center on tall enemy"
    end

    test "explosion is at same position for square enemies" do
      state = %{
        game_width: 800,
        game_height: 600,
        score_multiplier: 10,
        enemies: [],
        explosions: [],
        players: %{
          "p1" => %{
            score: 0,
            alive: true
          }
        }
      }

      # angular is 100x100 — same as explosion size, so no offset needed
      enemy = %Flappy.Enemy{
        position: {300.0, 200.0, 37.5, 33.3},
        velocity: {-75.0, 0},
        sprite: %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
        id: "square-enemy"
      }

      state = %{state | enemies: [enemy]}
      new_state = Flappy.Enemy.remove_hit_enemies(state, [enemy], "p1")

      [explosion] = new_state.explosions
      {_, _, exp_x, exp_y} = explosion.position
      {_, _, enemy_x, enemy_y} = enemy.position

      # For 100x100 enemy with 100x100 explosion, offset should be 0
      assert_in_delta exp_x, enemy_x, 0.01
      assert_in_delta exp_y, enemy_y, 0.01
    end
  end
end
