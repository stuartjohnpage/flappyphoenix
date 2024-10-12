defmodule Flappy.Position do
  @moduledoc """
  Position functions
  """
  def get_percentage_position({x_position, y_position}, game_width, game_height) do
    percentage_x = x_position / game_width * 100
    percentage_y = y_position / game_height * 100

    {percentage_x, percentage_y}
  end

  def bird_x_eye_position(x_pos, %{player_size: {w, _h}, game_width: game_width}) do
    w = w / game_width * 100
    x_pos + w * 0.81
  end

  def bird_y_eye_position(y_pos, %{player_size: {_w, h}, game_height: game_height}) do
    h = h / game_height * 100
    y_pos + h * 0.05
  end
end
