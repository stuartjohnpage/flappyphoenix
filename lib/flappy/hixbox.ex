defmodule Flappy.Hitbox do
  @moduledoc false
  def overlap?({rect1_x, rect1_y, rect1_w, rect1_h}, {rect2_x, rect2_y, rect2_w, rect2_h}) do
    rect1_x < rect2_x + rect2_w &&
      rect1_x + rect1_w > rect2_x &&
      rect1_y < rect2_y + rect2_h &&
      rect1_y + rect1_h > rect2_y
  end
end
