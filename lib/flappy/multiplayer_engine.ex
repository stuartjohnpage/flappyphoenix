defmodule Flappy.MultiplayerEngine do
  @moduledoc """
  Global multiplayer game server. One instance for all multiplayer players.
  Manages shared game state, player join/leave, and broadcasts via PubSub.
  """

  use GenServer

  require Logger

  alias Flappy.GameState
  alias Flappy.MultiplayerScores

  @pubsub_topic "flappy:multiplayer"

  # --- Client API ---

  @global_name {:global, __MODULE__}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: @global_name)
  end

  def join(player_id, player_name) do
    GenServer.call(@global_name, {:join, player_id, player_name})
  end

  def leave(player_id) do
    GenServer.cast(@global_name, {:leave, player_id})
  end

  def get_state do
    GenServer.call(@global_name, :get_state)
  end

  def player_input(player_id, action) do
    GenServer.cast(@global_name, {:input, player_id, action})
  end

  def update_viewport(zoom_level, game_width, game_height) do
    GenServer.cast(@global_name, {:update_viewport, zoom_level, game_width, game_height})
  end

  def pubsub_topic, do: @pubsub_topic

  # --- Server ---

  @impl true
  def init(:ok) do
    Process.put(:pid_to_player, %{})
    {:ok, fresh_state()}
  end

  @impl true
  def handle_call({:join, player_id, player_name}, {caller_pid, _tag}, state) do
    pid_map = Process.get(:pid_to_player, %{})

    # Clean up any existing player for this LiveView process (handles rejoin)
    state =
      case Map.get(pid_map, caller_pid) do
        nil -> state
        old_player_id ->
          Process.put(:pid_to_player, Map.delete(pid_map, caller_pid))
          do_leave(state, old_player_id)
      end

    # Monitor the LiveView process for automatic cleanup on disconnect
    unless Map.has_key?(Process.get(:pid_to_player, %{}), caller_pid) do
      Process.monitor(caller_pid)
    end

    needs_fresh_start = map_size(state.players) == 0 || state.game_over

    state =
      if needs_fresh_start do
        stop_timers(state)
        state = fresh_state()
        state = GameState.add_player(state, player_id, player_name)
        start_timers(state)
        state
      else
        GameState.add_player(state, player_id, player_name)
      end

    # Track pid → player_id mapping
    Process.put(:pid_to_player, Map.put(Process.get(:pid_to_player, %{}), caller_pid, player_id))

    {:reply, :ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:leave, player_id}, state) do
    # Clean up pid → player mapping
    pid_map = Process.get(:pid_to_player, %{})
    pid_map = pid_map |> Enum.reject(fn {_pid, id} -> id == player_id end) |> Map.new()
    Process.put(:pid_to_player, pid_map)

    {:noreply, do_leave(state, player_id)}
  end

  def handle_cast({:input, player_id, action}, state) do
    {:noreply, GameState.handle_input(state, player_id, action)}
  end

  def handle_cast({:update_viewport, zoom_level, game_width, game_height}, state) do
    {:noreply, %{state | zoom_level: zoom_level, game_width: game_width, game_height: game_height}}
  end

  @impl true
  def handle_info(:game_tick, %{game_over: true} = state) do
    {:noreply, state}
  end

  def handle_info(:game_tick, state) do
    if map_size(state.players) == 0 do
      {:noreply, state}
    else
      case GameState.tick(state) do
        {:game_over, state} ->
          save_deaths_this_tick(state)
          stop_timers(state)
          broadcast(state)
          {:noreply, state}

        {:ok, state} ->
          save_deaths_this_tick(state)
          broadcast(state)
          {:noreply, state}
      end
    end
  end

  def handle_info(:score_tick, %{game_over: true} = state) do
    {:noreply, state}
  end

  def handle_info(:score_tick, state) do
    if map_size(state.players) == 0 do
      {:noreply, state}
    else
      {:noreply, GameState.score_tick(state)}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    pid_map = Process.get(:pid_to_player, %{})

    case Map.pop(pid_map, pid) do
      {nil, _} ->
        {:noreply, state}

      {player_id, new_pid_map} ->
        Process.put(:pid_to_player, new_pid_map)
        {:noreply, do_leave(state, player_id)}
    end
  end

  # --- Private ---

  defp fresh_state do
    %GameState{
      game_id: "multiplayer",
      game_tick_interval: 15,
      score_tick_interval: 1000,
      score_multiplier: 10,
      difficulty_score: 400,
      game_over: false,
      game_height: 600,
      game_width: 800,
      zoom_level: 1,
      gravity: 175,
      enemies: [],
      power_ups: [],
      players: %{},
      explosions: [],
      deaths_this_tick: []
    }
  end

  defp start_timers(state) do
    {:ok, game_ref} = :timer.send_interval(state.game_tick_interval, self(), :game_tick)
    {:ok, score_ref} = :timer.send_interval(state.score_tick_interval, self(), :score_tick)
    Process.put(:game_timer, game_ref)
    Process.put(:score_timer, score_ref)
  end

  defp stop_timers(_state) do
    game_ref = Process.get(:game_timer)
    score_ref = Process.get(:score_timer)
    if game_ref, do: :timer.cancel(game_ref)
    if score_ref, do: :timer.cancel(score_ref)
    Process.delete(:game_timer)
    Process.delete(:score_timer)
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      Flappy.PubSub,
      @pubsub_topic,
      {:multiplayer_state, GameState.strip_hitboxes(state)}
    )
  end

  # Save scores for players who died this tick (used for both mid-game deaths and game_over)
  defp save_deaths_this_tick(state) do
    Enum.each(state.deaths_this_tick, fn player_id ->
      player = state.players[player_id]
      if player, do: save_score(player, state)
    end)
  end

  defp save_score(player, state) do
    survival_ms = Map.get(player, :survival_time, 0) * state.score_tick_interval

    if survival_ms > 0 do
      try do
        case MultiplayerScores.save_score(player.name, survival_ms) do
          {:ok, _} -> :ok
          {:error, reason} -> Logger.error("Failed to save multiplayer score: #{inspect(reason)}")
        end
      rescue
        e -> Logger.error("Failed to save multiplayer score: #{Exception.message(e)}")
      end
    end
  end

  defp do_leave(state, player_id) do
    player = state.players[player_id]

    if player do
      if Map.get(player, :alive, true), do: save_score(player, state)

      state = GameState.remove_player(state, player_id)
      broadcast(state)

      if map_size(state.players) == 0 do
        stop_timers(state)
        fresh_state()
      else
        state
      end
    else
      state
    end
  end
end
