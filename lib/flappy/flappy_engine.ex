defmodule Flappy.FlappyEngine do
  @moduledoc """
  This module serves as the backbone of the FlappyPhoenix game, orchestrating all game logic and state management.

  It orchestrates:

  - Game initialization and state management
  - Player movement and controls
  - Enemy and power-up generation and updates
  - Collision detection and game-over conditions
  - Score tracking and difficulty progression
  - Periodic game state updates and broadcasts

  The engine provides a public API for starting/stopping the game, retrieving game state,
  and controlling the player's actions.
  """

  use GenServer

  alias Flappy.Enemy
  alias Flappy.Explosion
  alias Flappy.Hitbox
  alias Flappy.Players
  alias Flappy.Players.Player
  alias Flappy.Position
  alias Flappy.PowerUp

  # TIME VARIABLES
  @game_tick_interval 30
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @gravity 175
  @thrust -100
  @start_score 0

  ### GAME MULTIPLIERS
  @difficulty_score 500
  @score_multiplier 10

  @power_up_sprites [
    %{image: "/images/laser.svg", size: {50, 50}, name: :laser},
    %{image: "/images/bomb.svg", size: {50, 50}, name: :bomb}
  ]

  @player_sprites [
    %{image: "/images/flipped_phoenix.svg", size: {128, 89}, name: :phoenix},
    %{image: "/images/laser_phoenix.svg", size: {128, 89}, name: :laser_phoenix},
    %{image: "/images/test_blue.svg", size: {100, 100}, name: :test}
  ]

  @enemy_sprites [
    %{image: "/images/ruby_rails.svg", size: {397, 142}, name: :ruby_rails},
    %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
    %{image: "/images/node.svg", size: {100, 100}, name: :node}
  ]

  # Game state
  defstruct game_id: nil,
            current_high_scores: [],
            game_over: false,
            game_height: 0,
            game_width: 0,
            zoom_level: 1,
            gravity: 0,
            laser_allowed: false,
            laser_beam: false,
            laser_duration: 0,
            enemies: [%Enemy{}],
            power_ups: [%PowerUp{}],
            player: %Player{},
            explosions: [%Explosion{}]

  @impl true
  def init(%{
        game_height: game_height,
        game_width: game_width,
        game_id: game_id,
        player_name: player_name,
        zoom_level: zoom_level
      }) do
    gravity = @gravity / zoom_level
    max_generation_height = round(game_height - game_height / 4)
    player = Players.create_player!(%{name: player_name, score: @start_score, version: get_game_version()})
    current_high_scores = Players.get_current_high_scores()

    state = %__MODULE__{
      current_high_scores: current_high_scores,
      game_over: false,
      game_id: game_id,
      game_height: game_height,
      game_width: game_width,
      gravity: gravity,
      zoom_level: zoom_level,
      player: %{
        player
        | position: {0, game_height / 2, 0, game_height / 2},
          velocity: {0, 0},
          sprite: List.first(@player_sprites),
          granted_powers: []
      },
      enemies: [
        %Enemy{
          position: {game_width, Enum.random(0..max_generation_height), 100, Enum.random(0..100)},
          velocity: {Enum.random(-100..-50), 0},
          sprite: Enum.random(@enemy_sprites),
          id: UUID.uuid4()
        }
      ],
      power_ups: [
        %PowerUp{
          position: {game_width / 2, 0, 50, 0},
          velocity: {0, Enum.random(50..100)},
          sprite: Enum.random(@power_up_sprites),
          id: UUID.uuid4()
        }
      ],
      explosions: []
    }

    # Start the periodic update
    :timer.send_interval(@game_tick_interval, self(), :game_tick)
    :timer.send_interval(@score_tick_interval, self(), :score_tick)
    {:ok, state}
  end

  @impl true
  def handle_cast(:go_up, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = y_velocity + @thrust / zoom_level
    player = %{player | velocity: {x_velocity, new_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_down, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = y_velocity - @thrust / zoom_level
    player = %{player | velocity: {x_velocity, new_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_right, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = x_velocity - @thrust / zoom_level

    player = %{player | velocity: {new_velocity, y_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_left, %{player: player, zoom_level: zoom_level} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = x_velocity + @thrust / zoom_level

    player = %{player | velocity: {new_velocity, y_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:fire_laser, state) do
    if state.laser_allowed do
      {:noreply, %{state | laser_beam: true, laser_duration: 3}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(
        :game_tick,
        %{game_id: game_id, player: %{sprite: %{size: {player_length, player_height}}} = player} = state
      ) do
    state =
      state
      |> update_player()
      |> update_enemies()
      |> update_power_ups()
      |> update_explosions()

    {x_pos, y_pos, _, _} = player.position

    collision? =
      Hitbox.check_for_enemy_collisions?(state)

    enemies_hit_by_beam =
      if state.laser_beam,
        do: Hitbox.get_hit_enemies(state.enemies, state),
        else: []

    power_ups_hit = Hitbox.get_hit_power_ups(state.power_ups, state)

    state =
      state
      |> remove_hit_enemies(enemies_hit_by_beam)
      |> grant_power_ups(power_ups_hit)

    cond do
      collision? ->
        calculate_score_and_update_view(state)

      y_pos < 0 ->
        calculate_score_and_update_view(state)

      y_pos > state.game_height - player_height ->
        calculate_score_and_update_view(state)

      x_pos < 0 ->
        calculate_score_and_update_view(state)

      x_pos > state.game_width - player_length ->
        calculate_score_and_update_view(state)

      true ->
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, %{player: player} = state) do
    granted_powers =
      player.granted_powers
      |> Enum.map(fn
        {_power, 0} -> nil
        {power, duration_left} -> {power, duration_left - 1}
      end)
      |> Enum.reject(&is_nil/1)

    player = %{player | score: player.score + 1, granted_powers: granted_powers}
    state = %{state | player: player}
    state = if rem(player.score, 2) == 0, do: %{state | enemies: generate_enemy(state)}, else: state
    state = if rem(player.score, 10) == 0, do: %{state | power_ups: generate_power_up(state)}, else: state

    {:noreply, state}
  end

  ## PRIVATE FUNCTIONS

  ### UPDATE FUNCTIONS

  defp update_player(
         %{
           player: player,
           gravity: gravity,
           game_width: game_width,
           game_height: game_height,
           laser_duration: laser_duration
         } = state
       ) do
    {x_position, y_position, _x_percent, _y_percent} = player.position
    {x_velocity, y_velocity} = player.velocity

    new_y_velocity = y_velocity + gravity * (@game_tick_interval / 1000)
    new_y_position = y_position + new_y_velocity * (@game_tick_interval / 1000)
    new_x_position = x_position + x_velocity * (@game_tick_interval / 1000)
    laser_on? = laser_duration > 0
    laser_duration = if laser_on?, do: laser_duration - 1, else: 0

    {x_percent, y_percent} = Position.get_percentage_position({new_x_position, new_y_position}, game_width, game_height)

    player = %{
      player
      | position: {new_x_position, new_y_position, x_percent, y_percent},
        velocity: {x_velocity, new_y_velocity}
    }

    %{
      state
      | player: player,
        laser_beam: laser_on?,
        laser_duration: laser_duration
    }
  end

  defp update_power_ups(state) do
    power_ups =
      state
      |> maybe_generate_power_up()
      |> Enum.map(fn power_up ->
        {x, y, _xpercent, _ypercent} = power_up.position
        {vx, vy} = power_up.velocity
        new_x = x + vx * (@game_tick_interval / 1000)
        new_y = y + vy * (@game_tick_interval / 1000)

        {x_percent, y_percent} = Position.get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        %{power_up | position: {new_x, new_y, x_percent, y_percent}}
      end)
      |> Enum.reject(fn power_up ->
        {x, _y, _, _} = power_up.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | power_ups: power_ups}
  end

  defp update_enemies(state) do
    enemies =
      state
      |> maybe_generate_enemy()
      |> Enum.map(fn enemy ->
        {x, y, _xpercent, _ypercent} = enemy.position
        {vx, vy} = enemy.velocity
        new_x = x + vx * (@game_tick_interval / 1000)
        new_y = y + vy * (@game_tick_interval / 1000)

        {x_percent, y_percent} = Position.get_percentage_position({new_x, new_y}, state.game_width, state.game_height)

        %{enemy | position: {new_x, new_y, x_percent, y_percent}}
      end)
      |> Enum.reject(fn enemy ->
        {x, _y, _, _} = enemy.position
        x < 0 - state.game_width / 100 * 25
      end)

    %{state | enemies: enemies}
  end

  defp grant_power_ups(%{player: player} = state, power_ups_hit) do
    hit_ids = Enum.map(power_ups_hit, & &1.id)

    {power_ups, granted_powers} =
      Enum.reduce(state.power_ups, {[], player.granted_powers}, fn power_up, {power_ups, granted_powers} ->
        if power_up.id in hit_ids do
          {power_ups, [{power_up.sprite.name, 5} | granted_powers]}
        else
          {[power_up | power_ups], granted_powers}
        end
      end)

    laser_allowed =
      Enum.any?(granted_powers, fn
        {:laser, duration} when duration > 0 -> true
        _ -> false
      end)

    {bomb_hit?, explosions} =
      Enum.reduce(power_ups_hit, {false, state.explosions}, fn power_up, {_bomb_hit, explosions} ->
        if power_up.sprite.name == :bomb do
          new_explosion = %Explosion{
            duration: 3,
            position: power_up.position,
            velocity: power_up.velocity,
            sprite: %{image: "/images/explosion.svg", size: {500, 500}, name: :explosion},
            id: UUID.uuid4()
          }

          {true, [new_explosion | explosions]}
        else
          {false, explosions}
        end
      end)

    {score, enemies} =
      if bomb_hit?,
        do: {player.score + length(state.enemies) * @score_multiplier, []},
        else: {player.score, state.enemies}

    player = %{player | granted_powers: granted_powers, score: score}

    %{
      state
      | power_ups: power_ups,
        player: player,
        laser_allowed: laser_allowed,
        enemies: enemies,
        explosions: explosions
    }
  end

  ### GENERATION FUNCTIONS

  defp maybe_generate_power_up(%{power_ups: power_ups} = state) do
    if Enum.random(1..1000) == 4 do
      # Generate a new power_up
      generate_power_up(state)
    else
      power_ups
    end
  end

  defp generate_power_up(state) do
    max_generation_width = round(state.game_width)

    [
      %PowerUp{
        position: {Enum.random(0..max_generation_width), 0, 0, 0},
        velocity: {0, Enum.random(100..150)},
        sprite: Enum.random(@power_up_sprites),
        id: UUID.uuid4()
      }
      | state.power_ups
    ]
  end

  defp maybe_generate_enemy(%{enemies: enemies, player: %{score: score}} = state) do
    # The game gets harder as the score increases
    difficultly_rating = if score < @difficulty_score - 5, do: score, else: @difficulty_score - 4
    difficultly_cap = @difficulty_score - difficultly_rating

    if Enum.random(1..difficultly_cap) == 4 do
      # Generate a new enemy
      generate_enemy(state)
    else
      enemies
    end
  end

  defp generate_enemy(%{enemies: enemies, game_height: game_height, game_width: game_width, zoom_level: zoom_level}) do
    max_generation_height = game_height
    enemy_sprite = Enum.random(@enemy_sprites)
    {_enemy_width, enemy_height} = enemy_sprite.size

    [
      %Enemy{
        position: {game_width, Enum.random(0..(max_generation_height - enemy_height)), 100, Enum.random(0..100)},
        velocity: {Enum.random(-100..-50) / zoom_level, 0},
        sprite: enemy_sprite,
        id: UUID.uuid4()
      }
      | enemies
    ]
  end

  defp update_explosions(%{explosions: explosions} = state) do
    explosions =
      Enum.reduce(explosions, [], fn explosion, acc ->
        if explosion.duration > 0 do
          [%{explosion | duration: explosion.duration - 1} | acc]
        else
          acc
        end
      end)

    %{state | explosions: explosions}
  end

  def remove_hit_enemies(%{player: player} = state, enemies_hit) do
    hit_ids = MapSet.new(enemies_hit, & &1.id)

    {enemies, new_explosions} =
      Enum.reduce(state.enemies, {[], []}, fn enemy, {remaining, explosions} ->
        if MapSet.member?(hit_ids, enemy.id) do
          explosion = %Explosion{
            duration: 3,
            position: enemy.position,
            velocity: enemy.velocity,
            sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
            id: UUID.uuid4()
          }

          {remaining, [explosion | explosions]}
        else
          {[enemy | remaining], explosions}
        end
      end)

    updated_score = player.score + length(new_explosions) * @score_multiplier
    player = %{player | score: updated_score}

    %{state | enemies: enemies, explosions: new_explosions ++ state.explosions, player: player}
  end

  defp calculate_score_and_update_view(
         %{player: player, game_id: game_id, current_high_scores: current_high_scores} = state
       ) do
    state = %{state | game_over: true}
    Players.update_player(player, %{score: player.score})
    high_score? = Enum.any?(current_high_scores, fn {_name, score} -> player.score > score end)

    if high_score?,
      do: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:high_score, state}),
      else: Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})

    Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
    {:noreply, state}
  end

  ### PUBLIC API
  def start_engine(game_height, game_width, player_name, zoom_level) do
    game_id = UUID.uuid4()

    GenServer.start_link(__MODULE__, %{
      game_height: game_height,
      game_width: game_width,
      game_id: game_id,
      player_name: player_name,
      zoom_level: zoom_level
    })
  end

  @spec stop_engine(atom() | pid() | {atom(), any()} | {:via, atom(), any()}) :: :ok
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

  def get_game_version do
    Application.get_env(:flappy, :game_version, "1")
  end
end
