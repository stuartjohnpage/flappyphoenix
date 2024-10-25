defmodule Flappy.Explosion do
  @moduledoc """
  A struct to represent an explosion in the game.
  It contains the position and velocity of the explosion.
  The position is a tuple of x and y coordinates, and the velocity is a tuple of x and y velocities.
  """
  defstruct duration: 0, position: {0, 0, 0, 0}, velocity: {0, 0}, sprite: %{image: "", size: {0, 0}, name: :atom}, id: ""

  def update_explosions(%{explosions: explosions} = state) do
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
end
