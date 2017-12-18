require Logger

defmodule Sector.State do
  defstruct players: %{}, asteroids: %{}
end

defmodule Sector.Player do
  @enforce_keys [:conn, :nickname, :coordinate]

  defstruct [
    :conn,
    :nickname,
    :coordinate,
  ]
end

defmodule Sector do
  use GenServer

  alias Astero.JoinAck
  alias Astero.OtherJoined
  alias Astero.Asteroids
  alias Astero.Spawn
  alias Astero.OtherLeft
  alias Astero.Coord

  alias Sector.State
  alias Sector.Player
  alias Sector.Asteroid

  @initial_asteroids_count 5
  @max_asteroids_count 10

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

    {:ok, %State{asteroids: asteroids}}
  end

  def handle_cast(msg, state) do
    case msg do
      {:joined, conn, player_id, nickname} ->
        coord = generate_coordinates()

        Lobby.Connection.send(conn, {:join_ack, JoinAck.new(pos: coord, id: player_id)})

        joined = OtherJoined.new(id: player_id, nickname: nickname, pos: coord)
        Lobby.broadcast({:other_joined, joined}, conn)

        Enum.each(state.players, fn {id, player} ->
          older_player = OtherJoined.new(id: id, nickname: player.nickname, pos: player.coordinate)
          Lobby.Connection.send(conn, {:other_joined, older_player})
        end)

        asteroids = Asteroids.new(asteroids: Map.values(state.asteroids))
        spawn_asteroids = Spawn.new(entity: {:asteroids, asteroids})
        Lobby.Connection.send(conn, {:spawn, spawn_asteroids})

        player = %Player{
          conn: conn,
          nickname: nickname,
          coordinate: coord,
        }

        {:noreply, %{state | players: Map.put(state.players, player_id, player)}}

      {:left, conn, player_id} ->
        player_left = OtherLeft.new(id: player_id)
        Lobby.broadcast({:other_left, player_left}, conn)

        {_player, players} = Map.pop(state.players, player_id)

        {:noreply, %{state | players: players}}
    end
  end

  defp generate_coordinates() do
    Coord.new(x: :rand.uniform(400) - 400.0, y: :rand.uniform(300) - 300.0)
  end
end
