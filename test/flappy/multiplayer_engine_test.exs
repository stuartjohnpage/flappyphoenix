defmodule Flappy.MultiplayerEngineTest do
  use ExUnit.Case, async: false

  alias Flappy.MultiplayerEngine

  setup do
    # Ensure clean engine state before each test
    state = MultiplayerEngine.get_state()

    for {player_id, _} <- state.players do
      MultiplayerEngine.leave(player_id)
    end

    # Give the async casts time to process
    Process.sleep(50)
    :ok
  end

  describe "rejoin cleanup" do
    test "joining again from same process removes old player" do
      :ok = MultiplayerEngine.join("player-old", "Alice")
      state = MultiplayerEngine.get_state()
      assert Map.has_key?(state.players, "player-old")

      # Rejoin from the same process (simulates clicking Rejoin)
      :ok = MultiplayerEngine.join("player-new", "Alice")
      state = MultiplayerEngine.get_state()

      refute Map.has_key?(state.players, "player-old"),
        "old player should be cleaned up on rejoin"

      assert Map.has_key?(state.players, "player-new")
      assert map_size(state.players) == 1

      MultiplayerEngine.leave("player-new")
    end

    test "ghost players don't accumulate across multiple rejoins" do
      :ok = MultiplayerEngine.join("id-1", "Alice")
      :ok = MultiplayerEngine.join("id-2", "Alice")
      :ok = MultiplayerEngine.join("id-3", "Alice")

      state = MultiplayerEngine.get_state()

      assert map_size(state.players) == 1, "should only have latest player, no ghosts"
      assert Map.has_key?(state.players, "id-3")
      refute Map.has_key?(state.players, "id-1")
      refute Map.has_key?(state.players, "id-2")

      MultiplayerEngine.leave("id-3")
    end

    test "leaving an already-cleaned-up player is a no-op" do
      :ok = MultiplayerEngine.join("will-rejoin", "Alice")
      :ok = MultiplayerEngine.join("after-rejoin", "Alice")

      # Old player was already cleaned up by rejoin. Leave it again — should be harmless.
      MultiplayerEngine.leave("will-rejoin")
      Process.sleep(50)

      state = MultiplayerEngine.get_state()
      assert Map.has_key?(state.players, "after-rejoin"),
        "new player should still exist after stale leave"

      MultiplayerEngine.leave("after-rejoin")
    end
  end

  describe "process monitoring" do
    test "player is removed when their process dies" do
      test_pid = self()

      {pid, ref} =
        spawn_monitor(fn ->
          :ok = MultiplayerEngine.join("monitored-player", "Bob")
          send(test_pid, :joined)
          receive do: (:stop -> :ok)
        end)

      assert_receive :joined, 1000

      state = MultiplayerEngine.get_state()
      assert Map.has_key?(state.players, "monitored-player")

      # Kill the process (simulates tab close / browser crash)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
      Process.sleep(50)

      state = MultiplayerEngine.get_state()

      refute Map.has_key?(state.players, "monitored-player"),
        "player should be auto-removed when process dies"
    end

    test "killing one process doesn't affect another player" do
      test_pid = self()

      {pid_a, ref_a} =
        spawn_monitor(fn ->
          :ok = MultiplayerEngine.join("proc-a", "Alice")
          send(test_pid, {:joined, :a})
          receive do: (:stop -> :ok)
        end)

      {pid_b, ref_b} =
        spawn_monitor(fn ->
          :ok = MultiplayerEngine.join("proc-b", "Bob")
          send(test_pid, {:joined, :b})
          receive do: (:stop -> :ok)
        end)

      assert_receive {:joined, :a}, 1000
      assert_receive {:joined, :b}, 1000

      state = MultiplayerEngine.get_state()
      assert map_size(state.players) == 2

      # Kill only process A
      Process.exit(pid_a, :kill)
      assert_receive {:DOWN, ^ref_a, :process, ^pid_a, :killed}
      Process.sleep(50)

      state = MultiplayerEngine.get_state()
      refute Map.has_key?(state.players, "proc-a")
      assert Map.has_key?(state.players, "proc-b"), "proc-b should still exist"

      # Cleanup
      Process.exit(pid_b, :kill)
      assert_receive {:DOWN, ^ref_b, :process, ^pid_b, :killed}
    end
  end

  describe "leave" do
    test "leave removes player from state" do
      :ok = MultiplayerEngine.join("leave-test", "Alice")
      state = MultiplayerEngine.get_state()
      assert Map.has_key?(state.players, "leave-test")

      MultiplayerEngine.leave("leave-test")
      Process.sleep(50)

      state = MultiplayerEngine.get_state()
      refute Map.has_key?(state.players, "leave-test")
    end

    test "leave for nonexistent player is a no-op" do
      MultiplayerEngine.leave("nonexistent")
      Process.sleep(50)

      # Engine should still be functional
      state = MultiplayerEngine.get_state()
      assert is_map(state.players)
    end
  end

  describe "fresh start" do
    test "joining after all players leave creates fresh state" do
      test_pid = self()

      {pid, ref} =
        spawn_monitor(fn ->
          :ok = MultiplayerEngine.join("temp-player", "Alice")
          send(test_pid, :joined)
          receive do: (:stop -> :ok)
        end)

      assert_receive :joined, 1000

      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
      Process.sleep(50)

      state = MultiplayerEngine.get_state()
      assert map_size(state.players) == 0

      # Join again — should get fresh state
      :ok = MultiplayerEngine.join("fresh-player", "Charlie")
      state = MultiplayerEngine.get_state()

      assert map_size(state.players) == 1
      assert Map.has_key?(state.players, "fresh-player")
      assert state.game_over == false

      MultiplayerEngine.leave("fresh-player")
    end
  end
end
