defmodule Polygons.DetectionTest do
  use ExUnit.Case, async: true

  alias Polygons.Detection
  alias Polygons.Polygon

  # -- helpers ---------------------------------------------------------------

  defp square(x, y, size) do
    Polygon.make([{x, y}, {x + size, y}, {x + size, y + size}, {x, y + size}])
  end

  defp triangle(x, y, base, height) do
    Polygon.make([{x, y + height}, {x + base / 2, y}, {x + base, y + height}])
  end

  # -- Polygon.make & coerce_floats -----------------------------------------

  describe "Polygon.make/1" do
    test "coerces integer vertices to floats" do
      poly = Polygon.make([{1, 2}, {3, 4}])
      assert poly.vertices == [{1.0, 2.0}, {3.0, 4.0}]
    end

    test "preserves float vertices" do
      poly = Polygon.make([{1.5, 2.5}])
      assert poly.vertices == [{1.5, 2.5}]
    end
  end

  # -- Polygon.center -------------------------------------------------------

  describe "Polygon.center/1" do
    test "centroid of a unit square at origin" do
      poly = square(0, 0, 2)
      {cx, cy} = Polygon.center(poly)
      assert_in_delta cx, 1.0, 0.01
      assert_in_delta cy, 1.0, 0.01
    end

    test "centroid of a translated square" do
      poly = square(10, 20, 4)
      {cx, cy} = Polygon.center(poly)
      assert_in_delta cx, 12.0, 0.01
      assert_in_delta cy, 22.0, 0.01
    end
  end

  # -- overlap? -------------------------------------------------------------

  describe "overlap?/2" do
    test "touching ranges overlap" do
      assert Detection.overlap?({0.0, 5.0}, {5.0, 10.0})
    end

    test "contained range overlaps" do
      assert Detection.overlap?({-1.0, -3.0}, {-6.1, 3.5})
    end

    test "disjoint ranges do not overlap" do
      refute Detection.overlap?({-1.0, 0.0}, {0.01, 1.0})
    end

    test "identical ranges overlap" do
      assert Detection.overlap?({2.0, 5.0}, {2.0, 5.0})
    end

    test "list form delegates correctly" do
      assert Detection.overlap?([{0.0, 3.0}, {2.0, 5.0}])
      refute Detection.overlap?([{0.0, 1.0}, {2.0, 3.0}])
    end
  end

  # -- normals_of_edges ------------------------------------------------------

  describe "normals_of_edges/1" do
    test "returns one normal per edge" do
      poly = square(0, 0, 1)
      normals = Detection.normals_of_edges(poly)
      assert length(normals) == 4
    end

    test "normals are perpendicular to edges" do
      poly = Polygon.make([{0, 0}, {1, 0}, {1, 1}, {0, 1}])
      normals = Detection.normals_of_edges(poly)

      # Each normal dotted with its edge should be zero
      edges =
        poly.vertices
        |> Enum.chunk_every(2, 1, [hd(poly.vertices)])
        |> Enum.map(fn [{x1, y1}, {x2, y2}] -> {x2 - x1, y2 - y1} end)

      Enum.zip(normals, edges)
      |> Enum.each(fn {{nx, ny}, {ex, ey}} ->
        dot = nx * ex + ny * ey
        assert_in_delta dot, 0.0, 1.0e-10, "normal should be perpendicular to edge"
      end)
    end
  end

  # -- collision? :accurate --------------------------------------------------

  describe "collision?/3 :accurate" do
    test "identical squares collide" do
      sq = square(0, 0, 10)
      assert Detection.collision?(sq, sq, :accurate)
    end

    test "overlapping squares collide" do
      assert Detection.collision?(square(0, 0, 10), square(5, 5, 10), :accurate)
    end

    test "adjacent (touching) squares collide" do
      # Edge-to-edge: overlap? counts touching as overlapping
      assert Detection.collision?(square(0, 0, 10), square(10, 0, 10), :accurate)
    end

    test "separated squares do not collide" do
      refute Detection.collision?(square(0, 0, 10), square(20, 0, 10), :accurate)
    end

    test "one square fully inside another" do
      big = square(0, 0, 100)
      small = square(40, 40, 5)
      assert Detection.collision?(big, small, :accurate)
    end

    test "separated along Y axis only" do
      refute Detection.collision?(square(0, 0, 5), square(0, 10, 5), :accurate)
    end

    test "near-miss with gap" do
      refute Detection.collision?(square(0, 0, 5), square(5.01, 0, 5), :accurate)
    end

    test "triangles overlapping" do
      t1 = triangle(0, 0, 10, 10)
      t2 = triangle(5, 0, 10, 10)
      assert Detection.collision?(t1, t2, :accurate)
    end

    test "triangles separated" do
      t1 = triangle(0, 0, 5, 5)
      t2 = triangle(20, 0, 5, 5)
      refute Detection.collision?(t1, t2, :accurate)
    end

    test "triangle and square overlapping" do
      t = triangle(0, 0, 10, 10)
      s = square(3, 3, 5)
      assert Detection.collision?(t, s, :accurate)
    end

    test "default method is :accurate" do
      refute Detection.collision?(square(0, 0, 5), square(20, 0, 5))
      assert Detection.collision?(square(0, 0, 10), square(5, 5, 10))
    end
  end

  # -- collision? :fast ------------------------------------------------------

  describe "collision?/3 :fast" do
    test "clearly overlapping squares detected" do
      assert Detection.collision?(square(0, 0, 10), square(5, 5, 10), :fast)
    end

    test "clearly separated squares not detected" do
      refute Detection.collision?(square(0, 0, 5), square(50, 50, 5), :fast)
    end

    test "identical polygons detected" do
      sq = square(0, 0, 10)
      assert Detection.collision?(sq, sq, :fast)
    end
  end

  # -- game-realistic scenarios ----------------------------------------------

  describe "game-realistic hitbox scenarios" do
    test "player-shaped polygon collides with enemy-shaped polygon at same position" do
      # Simulate player hitbox at (10, 10) on an 800×600 game
      player = Polygons.Polygon.make([
        {10.0, 13.0},
        {11.25, 11.5},
        {15.0, 10.0},
        {16.25, 10.5},
        {15.0, 13.0},
        {11.875, 15.0}
      ])

      # Enemy diamond at same area
      enemy = Polygons.Polygon.make([
        {10.625, 11.66},
        {16.25, 10.0},
        {22.5, 11.66},
        {21.375, 14.66},
        {16.25, 16.66},
        {10.625, 14.66}
      ])

      assert Detection.collision?(player, enemy, :accurate)
    end

    test "player and far-away enemy do not collide" do
      player = Polygons.Polygon.make([
        {10.0, 13.0},
        {11.25, 11.5},
        {15.0, 10.0},
        {16.25, 10.5},
        {15.0, 13.0},
        {11.875, 15.0}
      ])

      enemy = Polygons.Polygon.make([
        {80.0, 80.0},
        {85.0, 78.0},
        {90.0, 80.0},
        {89.0, 84.0},
        {85.0, 86.0},
        {81.0, 84.0}
      ])

      refute Detection.collision?(player, enemy, :accurate)
      refute Detection.collision?(player, enemy, :fast)
    end

    test "laser beam (thin rectangle) intersects enemy" do
      laser = Polygons.Polygon.make([
        {15.0, 50.0},
        {100.0, 50.0},
        {100.0, 50.1},
        {15.0, 50.1}
      ])

      enemy = Polygons.Polygon.make([
        {50.0, 45.0},
        {60.0, 45.0},
        {60.0, 55.0},
        {50.0, 55.0}
      ])

      assert Detection.collision?(laser, enemy, :accurate)
    end

    test "laser beam misses enemy above it" do
      laser = Polygons.Polygon.make([
        {15.0, 50.0},
        {100.0, 50.0},
        {100.0, 50.1},
        {15.0, 50.1}
      ])

      enemy = Polygons.Polygon.make([
        {50.0, 30.0},
        {60.0, 30.0},
        {60.0, 40.0},
        {50.0, 40.0}
      ])

      refute Detection.collision?(laser, enemy, :accurate)
    end
  end
end
