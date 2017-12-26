require Logger

defmodule Sector.Player do
  @enforce_keys [:conn, :nickname, :body, :input]

  @player_size 25.0
  @player_initial_vel Astero.Coord.new(x: 0.0, y: 0.0)
  @player_initial_rot 0.0
  @player_rvel 2.05

  defstruct [
    :conn,
    :nickname,
    :body,
    :input,
    acceleration: {60.0, 10.0},
    latency: 0,
    last_input_update_time: 0,
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
      input: Astero.Input.new(turn: 0, accel: 0),
    }
  end

  def update_input(player, %Astero.Input{} = update, world_bounds) do
    turn = if update.turn == nil, do: player.input.turn, else: update.turn
    accel = if update.accel == nil, do: player.input.accel, else: update.accel

    player = %{player | input: %{player.input | turn: turn, accel: accel}}

    now = System.system_time(:milliseconds)

    dt = Enum.min([player.latency, now - player.last_input_update_time]) / 1000.0
    dt = if update.turn == 0 or update.accel == 0, do: -dt, else: dt

    player = update_body(player, dt, world_bounds)

    %{player | last_input_update_time: now}
  end

  def update_latency(player, then) do
    now = System.system_time(:milliseconds)
    latency = (now - then) / 2

    %{player | latency: latency}
  end

  def update_body(player, dt, world_bounds) do
    body = player.body
      |> Sector.State.rotate_body(dt, player.input.turn)
      |> Sector.State.accelerate_body(dt, player.input.accel, player.acceleration)
      |> Sector.State.update_body(dt)
      |> Sector.State.wrap_body(world_bounds)

    %{player | body: body}
  end
end