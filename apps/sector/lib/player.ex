require Logger

defmodule Sector.Player do
  alias Sector.Util.Math

  @enforce_keys [:conn, :nickname, :body, :input]

  @player_size 25.0
  @player_initial_vel Astero.Coord.new(x: 0.0, y: 0.0)
  @player_initial_rot 0.0
  @player_rvel 2.05
  @player_shot_timeout 0.5
  @shot_speed 200.0
  @shot_ttl 2.0
  @shot_size 6.0

  defstruct [
    :conn,
    :nickname,
    :body,
    :input,
    acceleration: {60.0, 10.0},
    latency: 0,
    last_input_update_time: 0,
    shot_timeout: 0.0,
    new_shot: nil,
  ]

  def random(conn, nickname, {x_bound, y_bound}) do
    coord = Astero.Coord.Impl.random(x_bound, y_bound)

    %Sector.Player {
      conn: conn,
      nickname: nickname,
      body: Astero.Body.new(
        pos: coord,
        vel: @player_initial_vel,
        size: @player_size,
        rvel: @player_rvel,
        rot: @player_initial_rot,
      ),
      input: Astero.Input.new(turn: 0, accel: 0, fire: false),
    }
  end

  def update_input(player, %Astero.Input{} = update, world_bounds) do
    turn = if update.turn == nil, do: player.input.turn, else: update.turn
    accel = if update.accel == nil, do: player.input.accel, else: update.accel
    fire = if update.fire == nil, do: player.input.fire, else: update.fire

    player = %{player | input: %{player.input | turn: turn, accel: accel, fire: fire}}

    if update.fire == nil do
      now = System.system_time(:milliseconds)

      dt = Enum.min([player.latency, now - player.last_input_update_time]) / 1000.0
      dt = if update.turn == 0 or update.accel == 0, do: -dt, else: dt

      player = update_body(player, dt, world_bounds)

      %{player | last_input_update_time: now}
    else
      player
    end
  end

  def update_latency(player, then) do
    now = System.system_time(:milliseconds)
    measured_latency = (now - then) / 2

    avg_latency = if player.latency == 0.0 do
      measured_latency
    else
      0.28 * measured_latency + (1 - 0.28) * player.latency
    end

    %{player | latency: avg_latency}
  end

  def update_body(player, dt, world_bounds) do
    body = player.body
      |> Sector.State.rotate_body(dt, player.input.turn)
      |> Sector.State.accelerate_body(dt, player.input.accel, player.acceleration)
      |> Sector.State.update_body(dt)
      |> Sector.State.wrap_body(world_bounds)

    %{player | body: body}
  end

  def fire(player, dt) do
    cond do
      player.shot_timeout > 0.0 ->
        %{player | shot_timeout: player.shot_timeout - dt, new_shot: nil}

      player.shot_timeout <= 0.0 and player.input.fire ->
        {dx, dy} = Math.vector_from_angle(player.body.rot)
        vel = Astero.Coord.new(x: dx * @shot_speed, y: dy * @shot_speed)
        body = Astero.Body.new(pos: player.body.pos, vel: vel, rot: player.body.rot, size: @shot_size)
        new_shot = Astero.Shot.new(body: body, ttl: @shot_ttl)

        %{player | shot_timeout: @player_shot_timeout, new_shot: new_shot}

      true -> player
    end
  end
end
