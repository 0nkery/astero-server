require Logger

defmodule Sector.Asteroid do
  alias Sector.Util.Math
  alias Sector.Asteroid

  @enforce_keys [:coordinate, :velocity]

  defstruct [
    :coordinate,
    :velocity,
    facing: 0.0,
    rvel: 0.0,
    life: 2.0,
  ]

  @max_asteroid_velocity 50.0

  def create_asteroids(count, min_radius, max_radius, {x, y} \\ {0, 0})
      when min_radius < max_radius
  do
    for _ <- 1..count do
      angle = :rand.uniform() * 2.0 * :math.pi
      distance = :rand.uniform() * (max_radius - min_radius) + min_radius
      {vx, vy} = Math.vector_from_angle(angle)
      coordinate = {x + vx * distance, y + vy * distance}
      velocity = Math.random_vector(@max_asteroid_velocity)

      %Asteroid{
        coordinate: coordinate,
        velocity: velocity
      }
    end
  end

  def to_binary(%Asteroid{coordinate: {x, y}, velocity: {vx, vy}} = asteroid) do
    <<
      x :: float,
      y :: float,
      vx :: float,
      vy :: float,
      asteroid.facing :: float,
      asteroid.rvel :: float,
      asteroid.life :: float,
    >>
  end
end
