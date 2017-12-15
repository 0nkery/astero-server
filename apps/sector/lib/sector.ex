require Logger

defmodule Sector.State do
  defstruct players: %{}
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
    {:ok, %State{}}
  end

  def handle_cast(msg, state) do
    case msg do
      {:joined, conn, player_id, nickname} ->
        x = :rand.uniform(400) - 400
        y = :rand.uniform(300) - 300

        ack = Lobby.Msg.ack(player_id, {x, y})
        Lobby.Connection.send(conn, ack)

        player_joined = Lobby.Msg.player_joined(player_id, nickname, {x, y})
        Lobby.broadcast(player_joined, conn)

        player = %Player{
          conn: conn,
          nickname: nickname,
          coordinate: {x, y},
        }

        {:noreply, %{state | players: Map.put(state.players, player_id, player)}}

      {:left, conn, player_id} ->
        player_left = Lobby.Msg.player_left(player_id)
        Lobby.broadcast(player_left, conn)

        {:noreply, state}
    end
  end
end
