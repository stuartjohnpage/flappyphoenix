defmodule Polygons.Polygon do
  @moduledoc """
  An n-sided polygon.
  """
  defstruct vertices: []

  @doc """
  Make a polygon from a list of vertices (2-tuples).

  ## Example
  ```
  iex> Collidex.Geometry.Polygon.make([{1,2}, {2, 2}, {2,0}, {1,0} ])
  %Collidex.Geometry.Polygon{vertices: [{1,2}, {2, 2}, {2,0}, {1,0} ]}
  ```
  """
  def make(vertices) when is_list(vertices) do
    %__MODULE__{vertices: coerce_floats(vertices)}
  end

  @doc """
  computes the centroid of a polygon by accumulating an average of the vertices.
  """
  def center(polygon) do
    {result_x, result_y, _} =
      Enum.reduce(
        polygon.vertices,
        {0.0, 0.0, 1},
        fn {x, y}, {acc_x, acc_y, count} ->
          {acc_x - acc_x / count + x / count, acc_y - acc_y / count + y / count, count + 1}
        end
      )

    {result_x, result_y}
  end

  @doc """
  Convert the numeric parts of arguments to floats.  Accepts
  a single number, a 2-tuple of numbers, or a list of 2-tuples
  of numbers.

  ## Examples

  ```
  iex> Collidex.Utils.coerce_floats [ {1, 3}, {-1.5, -2} ]
  [ {1.0, 3.0}, {-1.5, -2.0} ]

  iex> Collidex.Utils.coerce_floats {1, 3}
  {1.0, 3.0}

  iex> Collidex.Utils.coerce_floats 6
  6.0

  ```
  """
  def coerce_floats(list) when is_list(list) do
    Enum.map(list, fn {a, b} -> {a / 1, b / 1} end)
  end

  def coerce_floats({a, b}) do
    {a / 1, b / 1}
  end

  def coerce_floats(num) do
    num / 1
  end
end
