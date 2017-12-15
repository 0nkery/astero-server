defmodule Sector.Util.Math do
  def vector_from_angle(angle) when is_float(angle) do
    {:math.sin(angle), :math.cos(angle)}
  end

  def random_vector(max_magnitude) when is_float(max_magnitude) do
    angle = :rand.uniform() * 2.0 * :math.pi
    mag = :rand.uniform() * max_magnitude
    {x, y} = vector_from_angle(angle)

    {x * mag, y * mag}
  end
end