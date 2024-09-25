defmodule Polygons.Detection do
  @moduledoc """
  Detects collisions between polygons using the separating
  axis theorem.  Has two variants, :fast and :accurate.  :fast
  will miss a few rare tyes of collisions but is much faster.
  """

  alias Graphmath.Vec2
  alias Polygons.Polygon

  @doc """
  Check if two polygons intersect. Return value is true if they overlap
  on the plane.

  Uses the separating Axis Theorem, and so can only perform accurate
  detection for convex polygons.

  The third argument, `method` allow you to select between a default,
  fully accurate implementation of the Separating Axis Theorem, or a
  faster method that only checks for separation on a single axis.

  If :fast is passed as the third argument, this function will use the
  shortcut method of only checking the centroid-to-centroid
  axis. This method is at least as fast, with much better worst-case
  performance and will correctly detect the vast  majority of collisions.
  It can, however, occasionally return a false positive for
  almost-colliding acute polygons (particularly triangles) at skew angles.
  """
  def collision?(poly1, poly2, type \\ :accurate)

  def collision?(poly1, poly2, :fast) do
    poly2
    |> Polygon.center()
    |> Vec2.subtract(Polygon.center(poly1))
    |> collision_on_axis?(poly1, poly2)
  end

  def collision?(poly1, poly2, :accurate) do
    axes_to_test =
      normals_of_edges(poly1) ++
        normals_of_edges(poly2)

    if Enum.any?(axes_to_test, &(!collision_on_axis?(&1, poly1, poly2))) do
      false
    else
      true
    end
  end

  defp collision_on_axis?(axis, poly1, poly2) do
    collision =
      [poly1, poly2]
      |> Enum.map(& &1.vertices)
      |> Enum.map(fn vertices ->
        Enum.map(vertices, &Vec2.dot(&1, axis))
      end)
      |> Enum.map(&Enum.min_max(&1))
      |> overlap?()

    if collision do
      true
    else
      false
    end
  end

  @doc """
  Returns a vector normal to each edge of the shape, in a right-handed
  coordinate space.
  """
  def normals_of_edges(%Polygon{} = shape) do
    {_, sides} =
      Enum.reduce(shape.vertices, {List.last(shape.vertices), []}, fn vertex, {prev, list} ->
        {vertex, [Vec2.subtract(vertex, prev) | list]}
      end)

    Enum.map(sides, &Vec2.perp(&1))
  end

  @doc """
  Given two numeric ranges as a pair of 2-tuples `{a1, a2}, {b1, b2}`, or
  a list containing a pair of 2-tuples `[{a1, a2}, {b1, b2}]` returns
  true if those ranges overlap.

  ## Examples

  ```
  iex> overlap?({0.0,5.0}, {5.0, 10.0})
  true

  iex> overlap?({-1.0, -3.0}, {-6.1, 3.5})
  true

  iex> overlap?({-1.0, 0.0}, {0.01, 1.0} )
  false

  ```
  """
  def overlap?({min1, max1}, {min2, max2}) do
    in_range?(min1, min2, max2) or
      in_range?(max1, min2, max2) or
      in_range?(min2, min1, max1) or
      in_range?(max2, min1, max1)
  end

  def overlap?([tuple1, tuple2]) do
    overlap?(tuple1, tuple2)
  end

  defp in_range?(a, b, c) when b > c do
    in_range?(a, c, b)
  end

  defp in_range?(a, b, c) do
    a >= b and a <= c
  end
end
