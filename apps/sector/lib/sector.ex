require Logger

defmodule Sector.State do
  defstruct players: %{}, asteroids: %{}
end

defmodule Sector.Player do
  @enforce_keys [:conn, :nickname, :body]

  @player_size 32.0
  @player_initial_vel Astero.Coord.new(x: 0.0, y: 0.0)

  defstruct [
    :conn,
    :nickname,
    :body,
  ]

  def random(conn, nickname) do
    coord = Astero.Coord.Impl.random(400, 300)

    %Sector.Player {
      conn: conn,
      nickname: nickname,
      body: Astero.Body.new(pos: coord, vel: @player_initial_vel, size: @player_size)
    }
  end
end

defmodule Sector do
  use GenServer

  alias Astero.JoinAck
  alias Astero.OtherJoined
  alias Astero.OtherLeft
  alias Astero.Asteroids
  alias Astero.Spawn
  alias Astero.Asteroid
  alias Astero.SimUpdates
  alias Astero.SimUpdate
  alias Astero.Entity

  alias Sector.State
  alias Sector.Player

  alias Sector.Simulation

  @initial_asteroids_count 5
  @max_asteroids_count 10
  @asteroid_spawn_rate 5000
  @simulation_update_rate 100

  # Client
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def player_joined(conn, player_id, nickname) do
    GenServer.cast(Sector, {:joined, conn, player_id, nickname})
  end

  def player_left(conn, player_id) do
    GenServer.cast(Sector, {:left, conn, player_id})
  end

  # Server
  def init(:ok) do
    Logger.info("Started #{__MODULE__}")

    asteroids = Asteroid.Impl.create_asteroids(@initial_asteroids_count, 100.0, 250.0)
    asteroids = Map.new(Enum.zip(1..@initial_asteroids_count, asteroids))

    Process.send_after(self(), :spawn, @asteroid_spawn_rate)
    Process.send_after(self(), :update_sim, @simulation_update_rate)

    {:ok, %State{asteroids: asteroids}}
  end

  def handle_cast(msg, state) do
    case msg do
      {:joined, conn, player_id, nickname} ->
        player = Player.random(conn, nickname)
        Lobby.Connection.send(conn, {:join_ack, JoinAck.new(body: player.body, id: player_id)})

        joined = OtherJoined.new(id: player_id, nickname: nickname, body: player.body)
        Lobby.broadcast({:other_joined, joined}, conn)

        Enum.each(state.players, fn {id, player} ->
          older_player = OtherJoined.new(id: id, nickname: player.nickname, body: player.body)
          Lobby.Connection.send(conn, {:other_joined, older_player})
        end)

        asteroids = Asteroids.new(entities: state.asteroids)
        spawn_asteroids = Spawn.new(entity: {:asteroids, asteroids})
        Lobby.Connection.send(conn, {:spawn, spawn_asteroids})

        {:noreply, %{state | players: Map.put(state.players, player_id, player)}}

      {:left, conn, player_id} ->
        player_left = OtherLeft.new(id: player_id)
        Lobby.broadcast({:other_left, player_left}, conn)

        {_player, players} = Map.pop(state.players, player_id)

        {:noreply, %{state | players: players}}
    end
  end

  def handle_info(msg, sector) do
    case msg do
      :spawn ->
        asteroids_count = Enum.count(sector.asteroids)

        sector = if asteroids_count == @max_asteroids_count do
          sector
        else
          new_id = asteroids_count + 1
          asteroid = Asteroid.Impl.create_asteroid(100.0, 300.0)

          asteroids = Asteroids.new(entities: %{new_id => asteroid})
          spawn_asteroids = Spawn.new(entity: {:asteroids, asteroids})
          Lobby.broadcast({:spawn, spawn_asteroids})

          Process.send_after(self(), :spawn, @asteroid_spawn_rate)

          %{sector | asteroids: Map.put(sector.asteroids, new_id, asteroid)}
        end

        {:noreply, sector}

      :update_sim ->
        sector = Simulation.update(sector, @simulation_update_rate / 1000.0, {800.0, 600.0})

        Process.send_after(self(), :update_sim, @simulation_update_rate)

        sim_updates = Enum.map(sector.asteroids, fn {id, asteroid} ->
          SimUpdate.new(
            entity: Entity.value(:ASTEROID),
            id: id,
            body: asteroid.body,
          )
        end)
        Lobby.broadcast({:sim_updates, SimUpdates.new(updates: sim_updates)})

        {:noreply, sector}
    end
  end
end
