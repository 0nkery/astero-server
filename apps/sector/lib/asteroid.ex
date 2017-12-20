require Logger

defmodule Sector.Asteroid.Impl do
  alias Sector.Util.Math
  alias Astero.Coord
  alias Astero.Asteroid

  @max_asteroid_velocity 50.0

  def create_asteroids(count, min_radius, max_radius, coord \\ {0, 0})
      when min_radius < max_radius
  do
    for _ <- 1..count do
      create_asteroid(min_radius, max_radius, coord)
    end
  end

  def create_asteroid(min_radius, max_radius, {x, y} \\ {0, 0})
    when min_radius < max_radius
  do
    angle = :rand.uniform() * 2.0 * :math.pi
    distance = :rand.uniform() * (max_radius - min_radius) + min_radius
    {vx, vy} = Math.vector_from_angle(angle)
    coordinate = Coord.new(x: x + vx * distance, y: y + vy * distance)
    {vx, vy} = Math.random_vector(@max_asteroid_velocity)
    velocity = Coord.new(x: vx, y: vy)

    Asteroid.new(pos: coordinate, velocity: velocity, life: 2.0)
  end
end
