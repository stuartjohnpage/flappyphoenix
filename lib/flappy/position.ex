defmodule Flappy.Position do
  @moduledoc """
  Position functions
  """
  def get_percentage_position({x_position, y_position}, game_width, game_height) do
    percentage_x = Float.floor(x_position / game_width * 100, 2)
    percentage_y = Float.floor(y_position / game_height * 100, 2)

    {percentage_x, percentage_y}
  end

  def bird_x_eye_position(%{player: %{sprite: %{size: {w, _h}}, position: {_, _, x_pos, _y_pos}}, game_width: game_width}) do
    w = w / game_width * 100
    x_pos + w * 0.81
  end

  def bird_y_eye_position(%{
        player: %{sprite: %{size: {_w, h}}, position: {_, _, _x_pos, y_pos}},
        game_height: game_height
      }) do
    h = h / game_height * 100
    y_pos + h * 0.05
  end
end
