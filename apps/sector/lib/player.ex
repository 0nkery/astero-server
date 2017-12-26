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

  def update_input(player, %Astero.Input{} = update) do
    turn = if update.turn == nil, do: player.input.turn, else: update.turn
    accel = if update.accel == nil, do: player.input.accel, else: update.accel

    %{
      player |
      input: %{player.input | turn: turn, accel: accel},
      last_input_update_time: System.system_time(:milliseconds),
    }
  end

  def update_latency(player, then) do
    now = System.system_time(:milliseconds)
    latency = (now - then) / 2

    Logger.debug(latency)

    %{player | latency: latency}
  end

  def update_body(player, world_bounds) do
    cond do
      player.input.turn == 0 and player.input.accel == 0 -> player
      true ->
        dt = Enum.min([player.latency, System.system_time(:milliseconds) - player.last_input_update_time])
        Logger.debug(dt)
        Sector.State.update_player(player, dt, world_bounds)
    end
  end
end