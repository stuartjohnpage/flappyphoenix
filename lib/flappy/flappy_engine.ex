defmodule Flappy.FlappyEngine do
  @moduledoc false
  use GenServer

  alias Flappy.Enemy
  alias Flappy.Explosion
  alias Flappy.Hitbox
  alias Flappy.Player
  alias Flappy.Position
  alias Flappy.PowerUp

  # TIME VARIABLES
  @game_tick_interval 30
  @score_tick_interval 1000

  ### VELOCITY VARIABLES
  @gravity 250
  @thrust -100
  @start_score 0

  ### GAME MULTIPLIERS
  @difficulty_score 500
  @score_multiplier 10

  @power_up_sprites [
    %{image: "/images/laser-warning.svg", size: {50, 50}, name: :laser}
  ]

  @player_sprites [
    %{image: "/images/flipped_phoenix.svg", size: {128, 89}, name: :phoenix},
    %{image: "/images/laser_phoenix.svg", size: {128, 89}, name: :laser_phoenix},
    %{image: "/images/test_blue.svg", size: {128, 89}, name: :test}
  ]

  @enemy_sprites [
    %{image: "/images/ruby_rails.svg", size: {397, 142}, name: :ruby_rails},
    %{image: "/images/angular_final.svg", size: {100, 100}, name: :angular},
    %{image: "/images/node.svg", size: {100, 100}, name: :node}
  ]

  # Game state
  defstruct game_id: nil,
            game_over: false,
            game_height: 0,
            game_width: 0,
            score: 0,
            gravity: 0,
            laser_allowed: false,
            laser_beam: false,
            laser_duration: 0,
            granted_powers: [],
            enemies: [%Enemy{}],
            power_ups: [%PowerUp{}],
            player: %Player{},
            explosions: [%Explosion{}]

  @impl true
  def init(%{game_height: game_height, game_width: game_width, game_id: game_id}) do
    gravity = @gravity / game_height * 500
    max_generation_height = round(game_height - game_height / 4)

    state = %__MODULE__{
      game_over: false,
      game_id: game_id,
      game_height: game_height,
      game_width: game_width,
      score: @start_score,
      gravity: gravity,
      player: %Player{
        position: {0, game_height / 2, 0, game_height / 2},
        velocity: {0, 0},
        sprite: List.first(@player_sprites),
        id: UUID.uuid4()
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
  def handle_cast(:go_up, %{player: player} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = y_velocity + @thrust
    player = %{player | velocity: {x_velocity, new_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_down, %{player: player} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = y_velocity - @thrust
    player = %{player | velocity: {x_velocity, new_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_right, %{player: player} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = x_velocity - @thrust

    player = %{player | velocity: {new_velocity, y_velocity}}
    {:noreply, %{state | player: player}}
  end

  def handle_cast(:go_left, %{player: player} = state) do
    {x_velocity, y_velocity} = player.velocity
    new_velocity = x_velocity + @thrust

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
        state = %{state | game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}

      y_pos < 0 ->
        state = %{state | game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}

      y_pos > state.game_height - player_height ->
        state = %{state | game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}

      x_pos < 0 ->
        state = %{state | game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}

      x_pos > state.game_width - player_length ->
        state = %{state | game_over: true}
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:global", {:new_score, state})
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}

      true ->
        Phoenix.PubSub.broadcast(Flappy.PubSub, "flappy:game_state:#{game_id}", {:game_state_update, state})
        {:noreply, state}
    end
  end

  def handle_info(:score_tick, state) do
    granted_powers =
      state.granted_powers
      |> Enum.map(fn
        {_power, 0} -> nil
        {power, duration_left} -> {power, duration_left - 1}
      end)
      |> Enum.reject(&is_nil/1)

    state = %{state | score: state.score + 1, granted_powers: granted_powers}
    state = if rem(state.score, 2) == 0, do: %{state | enemies: generate_enemy(state)}, else: state
    state = if rem(state.score, 10) == 0, do: %{state | power_ups: generate_power_up(state)}, else: state

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

  defp grant_power_ups(state, power_ups_hit) do
    hit_ids = Enum.map(power_ups_hit, & &1.id)

    {power_ups, granted_powers} =
      Enum.reduce(state.power_ups, {[], state.granted_powers}, fn power_up, {power_ups, granted_powers} ->
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

    %{state | power_ups: power_ups, granted_powers: granted_powers, laser_allowed: laser_allowed}
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

  defp maybe_generate_enemy(%{enemies: enemies, score: score} = state) do
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

  defp generate_enemy(%{enemies: enemies, game_height: game_height, game_width: game_width}) do
    max_generation_height = round(game_height - game_height / 4)

    [
      %Enemy{
        position: {game_width, Enum.random(0..max_generation_height), 100, Enum.random(0..100)},
        velocity: {Enum.random(-100..-50), 0},
        sprite: Enum.random(@enemy_sprites),
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

  def remove_hit_enemies(state, enemies_hit) do
    hit_ids = Enum.map(enemies_hit, & &1.id)
    enemies = Enum.reject(state.enemies, fn enemy -> enemy.id in hit_ids end)

    explosions =
      Enum.map(enemies_hit, fn hit_enemy ->
        %Explosion{
          duration: 3,
          position: hit_enemy.position,
          velocity: hit_enemy.velocity,
          sprite: %{image: "/images/explosion.svg", size: {100, 100}, name: :explosion},
          id: UUID.uuid4()
        }
      end)

    updated_score = state.score + Enum.count(enemies_hit) * @score_multiplier

    %{state | enemies: enemies, explosions: explosions, score: updated_score}
  end

  ### PUBLIC API
  def start_engine(game_height, game_width) do
    game_id = UUID.uuid4()
    GenServer.start_link(__MODULE__, %{game_height: game_height, game_width: game_width, game_id: game_id})
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
end
