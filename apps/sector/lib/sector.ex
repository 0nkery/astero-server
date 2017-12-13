require Logger

defmodule Sector.State do
  defstruct players: %{}
end

defmodule Sector do
  use GenServer

  alias Sector.State

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
        x = :rand.uniform(800)
        y = :rand.uniform(600)

        ack = Lobby.Msg.ack(player_id, {x, y})
        Lobby.Connection.send(conn, ack)

        player_joined = Lobby.Msg.player_joined(player_id, nickname, {x, y})
        Lobby.broadcast(player_joined, conn)

        {:noreply, state}

      {:left, conn, player_id} ->
        player_left = Lobby.Msg.player_left(player_id)
        Lobby.broadcast(player_left, conn)

        {:noreply, state}
    end
  end
end
