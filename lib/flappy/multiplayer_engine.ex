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

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def join(player_id, player_name) do
    GenServer.call(__MODULE__, {:join, player_id, player_name})
  end

  def leave(player_id) do
    GenServer.cast(__MODULE__, {:leave, player_id})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def player_input(player_id, action) do
    GenServer.cast(__MODULE__, {:input, player_id, action})
  end

  def update_viewport(zoom_level, game_width, game_height) do
    GenServer.cast(__MODULE__, {:update_viewport, zoom_level, game_width, game_height})
  end

  def pubsub_topic, do: @pubsub_topic

  # --- Server ---

  @impl true
  def init(:ok) do
    {:ok, fresh_state()}
  end

  @impl true
  def handle_call({:join, player_id, player_name}, _from, state) do
    needs_fresh_start = map_size(state.players) == 0 || state.game_over

    state =
      if needs_fresh_start do
        # First player or game_over: fresh state + start timers
        stop_timers(state)
        state = fresh_state()
        state = GameState.add_player(state, player_id, player_name)
        start_timers(state)
        state
      else
        GameState.add_player(state, player_id, player_name)
      end

    {:reply, :ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:leave, player_id}, state) do
    player = state.players[player_id]

    # Save survival time if player was alive
    if player && Map.get(player, :alive, true) do
      save_score(player, state)
    end

    state = GameState.remove_player(state, player_id)

    broadcast(state)

    # If no players left, stop timers and reset
    state =
      if map_size(state.players) == 0 do
        stop_timers(state)
        fresh_state()
      else
        state
      end

    {:noreply, state}
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
          # All players dead — save only those not already saved by handle_deaths
          save_unsaved_scores(state)
          stop_timers(state)
          broadcast(state)
          {:noreply, state}

        {:ok, state} ->
          handle_deaths(state)
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

  # Save scores for players who just died this tick
  defp handle_deaths(state) do
    Enum.each(state.deaths_this_tick, fn player_id ->
      player = state.players[player_id]
      if player, do: save_score(player, state)
    end)
  end

  # On game_over, only save players NOT already in deaths_this_tick
  # (those were already saved by handle_deaths in prior ticks)
  defp save_unsaved_scores(state) do
    already_saved = MapSet.new(state.deaths_this_tick)

    Enum.each(state.players, fn {player_id, player} ->
      unless MapSet.member?(already_saved, player_id) do
        save_score(player, state)
      end
    end)
  end

  defp save_score(player, state) do
    survival_ms = Map.get(player, :survival_time, 0) * state.score_tick_interval

    if survival_ms > 0 do
      case MultiplayerScores.save_score(player.name, survival_ms) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.error("Failed to save multiplayer score: #{inspect(reason)}")
      end
    end
  end
end
