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
    player = Players.create_player!(%{name: player_name, score: @start_score, version: get_game_version()})
    current_game_version = Application.get_env(:flappy, :game_version, "1")
    current_high_scores = Players.get_current_high_scores(5, current_game_version)

    state =
      GameState.new(
        game_id: game_id,
        game_height: game_height,
        game_width: game_width,
        zoom_level: zoom_level,
        gravity: 175 / zoom_level,
        current_high_scores: current_high_scores,
        player: %{
          Map.from_struct(player)
          | position: {100, game_height / 2, 10, 50},
            velocity: {0, 0},
            sprite: Players.get_sprite(),
            granted_powers: [],
            laser_allowed: false,
            laser_beam: false,
            laser_duration: 0,
            invincibility: false
        }
      )

    # Start the periodic update
    :timer.send_interval(state.game_tick_interval, self(), :game_tick)
    :timer.send_interval(state.score_tick_interval, self(), :score_tick)
    {:ok, state}
  end

  @impl true
  def handle_cast(input, state) do
    {:noreply, GameState.handle_input(state, input)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:game_tick, %{game_id: game_id} = state) do
    case GameState.tick(state) do
      {:game_over, state} ->
        calculate_score_and_update_view(state)

      {:ok, state} ->
        Phoenix.PubSub.broadcast(
          Flappy.PubSub,
          "flappy:game_state:#{game_id}",
          {:game_state_update, GameState.strip_hitboxes(state)}
        )

        {:noreply, state}
    end
  end

  def handle_info(:score_tick, state) do
    {:noreply, GameState.score_tick(state)}
  end

  defp calculate_score_and_update_view(
         %{player: player, game_id: game_id, current_high_scores: current_high_scores} = state
       ) do
    state = %{state | game_over: true}
    Players.update_player(player, %{score: player.score})
    high_score? = Enum.any?(current_high_scores, fn {_name, score} -> player.score > score end)

    broadcast_state = GameState.strip_hitboxes(state)

    if high_score?,
      do: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:high_score, broadcast_state}),
      else: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, broadcast_state})

    Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, broadcast_state})
    {:noreply, state}
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
