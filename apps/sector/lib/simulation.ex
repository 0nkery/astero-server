defmodule Sector.Simulation do
  alias Astero.Coord
  alias Astero.Asteroid

  alias Sector.Util.Math

  @max_velocity 250.0
  @max_velocity_sq @max_velocity * @max_velocity

  def update(%Sector.State{asteroids: asteroids} = sector, dt, {width, height}) do
    asteroids = for {id, %Asteroid{velocity: v, pos: p} = asteroid} <- asteroids, into: %{} do
      norm_squared = v.x * v.x + v.y * v.y

      {vx, vy} = if norm_squared > @max_velocity_sq do
        norm = :math.sqrt(norm_squared)
        {v.x / norm * @max_velocity, v.y / norm * @max_velocity}
      else
        {v.x, v.y}
      end

      {dvx, dvy} = {vx * dt, vy * dt}
      p = Coord.new(x: p.x + dvx, y: p.y + dvy)

      {id, %{asteroid | velocity: v, pos: p}}
    end

    {x_bound, y_bound} = {width / 2.0, height / 2.0}

    asteroids = for {id, %Asteroid{velocity: v, pos: p} = asteroid} <- asteroids, into: %{} do
      {cx, cy} = {p.x + 16, p.y - 16}
      v = cond do
        cx > x_bound or cx < -x_bound ->
          Math.reflect_vector(v, {0, height})
        cy > y_bound or cy < -y_bound ->
          Math.reflect_vector(v, {width, 0})
        true -> v
      end

      {id, %{asteroid | velocity: v}}
    end

    %{sector | asteroids: asteroids}
  end
end