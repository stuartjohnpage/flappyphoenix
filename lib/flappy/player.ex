defmodule Flappy.Player do
  @moduledoc """
  A struct to represent a player in the game.
  It contains the position and velocity of the player.
  The position is a tuple of x and y coordinates, and the velocity is a tuple of x and y velocities.
  """
  defstruct position: {0, 0, 0, 0}, velocity: {0, 0}, sprite: %{image: "", size: {0, 0}, name: :atom}, id: "", name: ""
end
