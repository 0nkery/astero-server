require Logger

defmodule Lobby.Connection.Player do
  @enforce_keys [:socket, :ip, :port, :conn_id]

  defstruct [
    :socket,
    :ip,
    :port,
    :conn_id,
    should_ping: false,
    missed_heartbeats: 0
  ]
end

defmodule Lobby.Connection do
  use GenServer, restart: :transient

  alias Lobby.Connection.Player

  # Client

  def start_link(_opts, {socket, ip, port, conn_id}) do
    GenServer.start_link(__MODULE__, %Player{
      socket: socket,
      ip: ip,
      port: port,
      conn_id: conn_id
    })
  end

  def process_packet(conn, packet) do
    GenServer.cast(conn, {:packet, packet})
  end

  def send(conn, packet) do
    GenServer.cast(conn, {:send, packet})
  end

  # Server

  def init(%Player{} = player) do
    Logger.debug("Player joined: #{inspect(player.ip)} #{inspect(player.port)} #{player.conn_id}")
    Process.send_after(self(), :ping, 5000)
    {:ok, player}
  end

  def handle_cast({:send, packet}, player) do
    :gen_udp.send(player.socket, player.ip, player.port, packet)
    {:noreply, player}
  end

  def handle_cast({:packet, packet}, player) do
    parse_packet(player, packet)
    {:noreply, player}
  end

  defp parse_packet(
     player,
     <<
       0 :: size(16),
       name_length :: size(8),
       nickname :: binary - size(name_length)
     >>
   ) do

    Logger.debug("New player nickname: #{nickname}")

    ack = Lobby.Msg.ack(player.conn_id)
    Lobby.Connection.send(self(), ack)

    player_joined = Lobby.Msg.player_joined(player.conn_id, name_length, nickname)
    Lobby.broadcast(player_joined, {player.ip, player.port})
  end

  defp parse_packet(
    player,
    <<
      1 :: size(16),
    >>
  ) do
    before_exit(player)
    Process.exit(self(), :normal)
  end

  defp parse_packet(player, unknown_message) do
    Logger.debug("Unknown message: #{unknown_message}")
    before_exit(player)
    Process.exit(self(), :normal)
  end

  defp before_exit(player) do
    Logger.debug("Player left: #{inspect(player.ip)}, #{inspect(player.port)}, #{player.conn_id}")
    Lobby.player_left(player.conn_id, player.ip, player.port)
  end
end
