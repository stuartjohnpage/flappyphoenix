defmodule Flappy.Players.Player do
  @moduledoc """
    A struct to represent a player in the game.
    It contains the position and velocity of the player.
    The position is a tuple of x and y coordinates, and the velocity is a tuple of x and y velocities.
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Flappy.Position

  @type t :: %__MODULE__{}

  schema "players" do
    ### Persisted fields
    field(:name, :string)
    field(:score, :integer)
    field(:version, :integer)

    field(:position, :any, virtual: true)
    field(:granted_powers, :any, virtual: true)
    field(:velocity, :any, virtual: true)
    field(:sprite, :map, virtual: true)
    field(:laser_allowed, :boolean, virtual: true)
    field(:laser_beam, :boolean, virtual: true)
    field(:laser_duration, :integer, virtual: true)
  end

  def changeset(player, params \\ %{}) do
    player
    |> Changeset.cast(params, [:name, :score, :version])
    |> Changeset.force_change(:score, Map.get(params, :score))
    |> Changeset.validate_required([:name, :score, :version])
  end

  def update_player(%{player: player, gravity: gravity, game_width: game_width, game_height: game_height} = state) do
    {x_position, y_position, _x_percent, _y_percent} = player.position
    {x_velocity, y_velocity} = player.velocity

    new_y_velocity = y_velocity + gravity * (state.game_tick_interval / 1000)
    new_y_position = y_position + new_y_velocity * (state.game_tick_interval / 1000)
    new_x_position = x_position + x_velocity * (state.game_tick_interval / 1000)
    laser_on? = player.laser_duration > 0
    laser_duration = if laser_on?, do: player.laser_duration - 1, else: 0

    {x_percent, y_percent} = Position.get_percentage_position({new_x_position, new_y_position}, game_width, game_height)

    player = %{
      player
      | position: {new_x_position, new_y_position, x_percent, y_percent},
        velocity: {x_velocity, new_y_velocity},
        laser_beam: laser_on?,
        laser_duration: laser_duration
    }

    %{state | player: player}
  end
end
