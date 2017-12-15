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

    asteroids = Asteroid.create_asteroids(@initial_asteroids_count, 100.0, 250.0)
    asteroids = Map.new(Enum.zip(1..@initial_asteroids_count, asteroids))

    {:ok, %State{asteroids: asteroids}}
  end

  def handle_cast(msg, state) do
    case msg do
      {:joined, conn, player_id, nickname} ->
        coord = generate_coordinates()

        ack = Lobby.Msg.ack(player_id, coord)
        Lobby.Connection.send(conn, ack)

        player_joined = Lobby.Msg.player_joined(player_id, nickname, coord)
        Lobby.broadcast(player_joined, conn)

        older_players = for {id, player} <- state.players do
          Lobby.Msg.player_joined(id, player.nickname, player.coordinate)
        end
        if Enum.count(older_players) > 0 do
          older_players = Lobby.Msg.composition(older_players)
          Lobby.Connection.send(conn, older_players)
        end

        spawn_asteroids = for {id, asteroid} <- state.asteroids do
          Lobby.Msg.asteroid(id, Asteroid.to_binary(asteroid))
        end
        spawn_asteroids = Lobby.Msg.composition(spawn_asteroids)
        Lobby.Connection.send(conn, spawn_asteroids)

        player = %Player{
          conn: conn,
          nickname: nickname,
          coordinate: coord,
        }

        {:noreply, %{state | players: Map.put(state.players, player_id, player)}}

      {:left, conn, player_id} ->
        player_left = Lobby.Msg.player_left(player_id)
        Lobby.broadcast(player_left, conn)

        {_player, players} = Map.pop(state.players, player_id)

        {:noreply, %{state | players: players}}
    end
  end

  defp generate_coordinates() do
    {:rand.uniform(400) - 400, :rand.uniform(300) - 300}
  end
end
