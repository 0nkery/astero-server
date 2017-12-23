defmodule Sector.Util.Math do
  alias Astero.Coord

  def vector_from_angle(angle) when is_float(angle) do
    {:math.sin(angle), :math.cos(angle)}
  end

  def random_vector(max_magnitude) when is_float(max_magnitude) do
    angle = :rand.uniform() * 2.0 * :math.pi
    mag = :rand.uniform() * max_magnitude
    {x, y} = vector_from_angle(angle)

    {x * mag, y * mag}
  end

  def reflect_vector(%Coord{} = v, {nx, ny}) do
    proj = 2 * (v.x * nx + v.y * ny) / (nx * nx + ny * ny)

    Coord.new(x: v.x - nx * proj, y: v.y - ny * proj)
  end
end


defmodule Sector.Coord.Impl do
  def random(x_abs_bound, y_abs_bound) do
    Astero.Coord.new(
      x: :rand.uniform(x_abs_bound * 2) - x_abs_bound * 1.0,
      y: :rand.uniform(y_abs_bound * 2) - y_abs_bound * 1.0
    )
  end
end