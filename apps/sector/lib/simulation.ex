require Logger

defmodule Sector.State do

  defstruct players: %{}, asteroids: %{}, shots: %{}, new_shots: []

  alias Astero.Coord
  alias Astero.Asteroid
  alias Astero.Body
  alias Astero.GameplayEvent
  alias Astero.EntityLifeUpdate
  alias Astero.Entity

  alias Sector.Player
  alias Sector.Util.Math

  @max_velocity 250.0
  @max_velocity_sq @max_velocity * @max_velocity

  def update(%Sector.State{} = sector, dt, bounds) do
    asteroids = for {id, %Asteroid{} = asteroid} <- sector.asteroids, into: %{} do
      body = asteroid.body
        |> update_body(dt)
        |> wrap_body(bounds)

      {id, %{asteroid | body: body}}
    end

    players = for {id, %Player{} = player} <- sector.players, into: %{} do
      updated = player
        |> Player.update_body(dt, bounds)
        |> Player.fire(dt)

      {id, updated}
    end

    new_shots = sector.players
      |> Enum.map(fn {_id, player} -> player.new_shot end)
      |> Enum.filter(fn shot -> shot != nil end)

    asteroid_player_collisions = Enum.flat_map(sector.players, fn {id, player} ->
      Enum.flat_map(sector.asteroids, fn {a_id, asteroid} ->
        if collided?(asteroid.body, player.body) do
          destroy_asteroid = EntityLifeUpdate.new(entity: Entity.value(:ASTEROID), id: a_id, life: 0.0)
          damage_player = EntityLifeUpdate.new(entity: Entity.value(:PLAYER), id: id, life: player.life - 1.0)

          [
            GameplayEvent.new(event: {:life_update, destroy_asteroid}),
            GameplayEvent.new(event: {:life_update, damage_player}),
          ]
        else
          []
        end
      end)
    end)

    events = asteroid_player_collisions

    {
      %{sector | asteroids: asteroids, players: players},
      new_shots,
      events,
    }
  end

  def rotate_body(%Body{rvel: rvel, rot: rot} = body, dt, direction) do
    rot = rot + dt * rvel * direction

    %{body | rot: rot}
  end

  def accelerate_body(%Body{vel: vel} = body, dt, direction, {forward, backward}) do
    v = if direction == 0 do
      vel
    else
      {angle, accel_value} = cond do
        direction > 0 -> {body.rot, forward}
        direction < 0 -> {body.rot + :math.pi, backward}
      end

      {dx, dy} = Math.vector_from_angle(angle)
      {ax, ay} = {dx * accel_value, dy * accel_value}

      Coord.new(x: vel.x + ax * dt, y: vel.y + ay * dt)
    end

    %{body | vel: v}
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

  def wrap_body(%Body{vel: v, pos: p, size: size} = body, {x_bound, y_bound}) do
    half_size = size / 2.0
    cx = if p.x > 0, do: p.x + half_size, else: p.x - half_size
    cy = if p.y > 0, do: p.y + half_size, else: p.y - half_size

    {nx, ny} = cond do
      cx > x_bound -> {-1, 0}
      cx < -x_bound -> {1, 0}
      cy > y_bound -> {0, -1}
      cy < -y_bound -> {0, 1}
      true -> {0, 0}
    end

    v = if (nx * v.x + ny * v.y) <= 0.0 do
      Math.reflect_vector(v, {nx, ny})
    else
      v
    end

    %{body | vel: v}
  end

  def collided?(first, second) do
    x_diff = second.pos.x - first.pos.x
    y_diff = second.pos.y - first.pos.y
    distance = :math.sqrt(x_diff * x_diff + y_diff * y_diff)

    distance < (first.size / 2.0 + second.size / 2.0)
  end
end