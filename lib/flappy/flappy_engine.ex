defmodule Flappy.FlappyEngine do
  @moduledoc """
  Thin GenServer shell around GameState. Owns timers, PubSub broadcasts, and DB writes.
  All game logic lives in GameState.
  """

  use GenServer

  alias Flappy.GameState
  alias Flappy.Players

  @start_score 0

  @impl true
  def init(%{
        game_height: game_height,
        game_width: game_width,
        game_id: game_id,
        player_name: player_name,
        zoom_level: zoom_level
      }) do
    player_id = Ecto.UUID.generate()
    db_player = Players.create_player!(%{name: player_name, score: @start_score, version: get_game_version()})
    current_game_version = Application.get_env(:flappy, :game_version, "1")
    current_high_scores = Players.get_current_high_scores(5, current_game_version)

    game_state =
      GameState.new(
        game_id: game_id,
        player_id: player_id,
        game_height: game_height,
        game_width: game_width,
        zoom_level: zoom_level,
        gravity: 175 / zoom_level,
        current_high_scores: current_high_scores,
        player: %{
          position: {100, game_height / 2, 10, 50},
          velocity: {0, 0},
          sprite: Players.get_sprite(),
          granted_powers: [],
          laser_allowed: false,
          laser_beam: false,
          laser_duration: 0,
          invincibility: false,
          name: player_name
        }
      )

    state = %{
      game_state: game_state,
      player_id: player_id,
      db_player: db_player
    }

    # Start the periodic update
    :timer.send_interval(game_state.game_tick_interval, self(), :game_tick)
    :timer.send_interval(game_state.score_tick_interval, self(), :score_tick)
    {:ok, state}
  end

  @impl true
  def handle_cast({:update_viewport, zoom_level, game_width, game_height}, %{game_state: gs, player_id: pid} = state) do
    {:noreply, %{state | game_state: GameState.handle_input(gs, pid, {:update_viewport, zoom_level, game_width, game_height})}}
  end

  def handle_cast(input, %{game_state: gs, player_id: pid} = state) do
    {:noreply, %{state | game_state: GameState.handle_input(gs, pid, input)}}
  end

  @impl true
  def handle_call(:get_state, _from, %{game_state: gs} = state) do
    {:reply, gs, state}
  end

  @impl true
  def handle_info(:game_tick, %{game_state: gs} = state) do
    case GameState.tick(gs) do
      {:game_over, gs} ->
        calculate_score_and_update_view(%{state | game_state: gs})

      {:ok, gs} ->
        Phoenix.PubSub.broadcast(
          Flappy.PubSub,
          "flappy:game_state:#{gs.game_id}",
          {:game_state_update, GameState.strip_hitboxes(gs)}
        )

        {:noreply, %{state | game_state: gs}}
    end
  end

  def handle_info(:score_tick, %{game_state: gs} = state) do
    {:noreply, %{state | game_state: GameState.score_tick(gs)}}
  end

  defp calculate_score_and_update_view(%{game_state: gs, player_id: player_id, db_player: db_player} = state) do
    player = gs.players[player_id]
    game_id = gs.game_id
    current_high_scores = gs.current_high_scores

    gs = %{gs | game_over: true}
    Players.update_player(db_player, %{score: player.score})
    high_score? = Enum.any?(current_high_scores, fn {_name, score} -> player.score > score end)

    broadcast_state = GameState.strip_hitboxes(gs)

    if high_score?,
      do: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:high_score, broadcast_state}),
      else: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, broadcast_state})

    Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, broadcast_state})
    {:noreply, %{state | game_state: gs}}
  end

  ### PUBLIC API
  def start_engine(game_height, game_width, player_name, zoom_level) do
    game_id = Ecto.UUID.generate()

    GenServer.start_link(__MODULE__, %{
      game_height: game_height,
      game_width: game_width,
      game_id: game_id,
      player_name: player_name,
      zoom_level: zoom_level
    })
  end

  def stop_engine(pid) do
    GenServer.stop(pid)
  end

  def get_game_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def go_up(pid) do
    GenServer.cast(pid, :go_up)
  end

  def go_down(pid) do
    GenServer.cast(pid, :go_down)
  end

  def go_right(pid) do
    GenServer.cast(pid, :go_right)
  end

  def go_left(pid) do
    GenServer.cast(pid, :go_left)
  end

  def fire_laser(pid) do
    GenServer.cast(pid, :fire_laser)
  end

  def update_viewport(pid, zoom_level, game_width, game_height) do
    GenServer.cast(pid, {:update_viewport, zoom_level, game_width, game_height})
  end

  def get_game_version do
    Application.get_env(:flappy, :game_version, "1")
  end
end
