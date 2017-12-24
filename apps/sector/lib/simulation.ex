defmodule Sector.State do

  defstruct players: %{}, asteroids: %{}

  alias Astero.Coord
  alias Astero.Asteroid
  alias Astero.Body

  alias Sector.Util.Math

  @max_velocity 250.0
  @max_velocity_sq @max_velocity * @max_velocity

  def update(%Sector.State{} = sector, dt, {width, height}) do
    {x_bound, y_bound} = {width / 2.0, height / 2.0}

    asteroids = for {id, %Asteroid{} = asteroid} <- sector.asteroids, into: %{} do
      body = asteroid.body
      |> update_body(dt)
      |> wrap_body(x_bound, y_bound)

      {id, %{asteroid | body: body}}
    end

    %{sector | asteroids: asteroids}
  end

  def update_body(%Body{vel: v, pos: p} = body, dt) do
    norm_squared = v.x * v.x + v.y * v.y

    {vx, vy} = if norm_squared > @max_velocity_sq do
      norm = :math.sqrt(norm_squared)
      {v.x / norm * @max_velocity, v.y / norm * @max_velocity}
    else
      {v.x, v.y}
    end

    {dvx, dvy} = {vx * dt, vy * dt}
    p = Coord.new(x: p.x + dvx, y: p.y + dvy)

    %{body | vel: v, pos: p}
  end

  def wrap_body(%Body{vel: v, pos: p} = body, x_bound, y_bound) do
    cx = if p.x > 0, do: p.x + 16.0, else: p.x - 16.0
    cy = if p.y > 0, do: p.y + 16.0, else: p.y - 16.0

    v = cond do
      cx > x_bound or cx < -x_bound ->
        Math.reflect_vector(v, {y_bound * 2.0, 0})
      cy > y_bound or cy < -y_bound ->
        Math.reflect_vector(v, {0, x_bound * 2.0})
      true -> v
    end

    %{body | vel: v}
  end
end