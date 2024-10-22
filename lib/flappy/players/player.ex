defmodule Flappy.Players.Player do
  @moduledoc """
    A struct to represent a player in the game.
    It contains the position and velocity of the player.
    The position is a tuple of x and y coordinates, and the velocity is a tuple of x and y velocities.
  """
  use Ecto.Schema

  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "players" do
    ### Persisted fields
    field(:name, :string)
    field(:score, :integer)
    field(:version, :integer)

    field(:position, :any, virtual: true)
    field(:velocity, :any, virtual: true)
    field(:sprite, :map, virtual: true)
  end

  def changeset(player, params \\ %{}) do
    player
    |> Changeset.cast(params, [:name, :score, :version])
    |> Changeset.force_change(:score, Map.get(params, :score))
    |> Changeset.validate_required([:name, :score, :version])
  end
end
