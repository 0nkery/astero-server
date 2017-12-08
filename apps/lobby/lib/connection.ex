require Logger

defmodule Lobby.Connection do
  use GenServer, restart: :transient

  def start_link(_opts, {socket, ip, port, conn_id}) do
    GenServer.start_link(__MODULE__, {socket, ip, port, conn_id})
  end

  def process_packet(conn, packet) do
    GenServer.cast(conn, {:packet, packet})
  end

  def send(conn, packet) do
    GenServer.cast(conn, {:send, packet})
  end

  def init({_socket, ip, port, _conn_id} = state) do
    Logger.debug("Got new connection: #{inspect(ip)} #{inspect(port)}")
    {:ok, state}
  end

  def handle_cast({:send, packet}, {socket, ip, port, _conn_id} = state) do
    :gen_udp.send(socket, ip, port, packet)
    {:noreply, state}
  end

  def handle_cast({:packet, packet}, state) do
    parse_packet(state, packet)
    {:noreply, state}
  end

  defp parse_packet(
     {_socket, ip, port, conn_id},
     <<
       0 :: size(16),
       name_length :: size(8),
       nickname :: binary - size(name_length)
     >>
   ) do

    Logger.debug("New player nickname: #{nickname}")

    ack = Lobby.Msg.ack(conn_id)
    Lobby.Connection.send(self(), ack)

    player_joined = Lobby.Msg.player_joined(conn_id, name_length, nickname)
    Lobby.broadcast(player_joined, {ip, port})
  end

  defp parse_packet(
    state,
    <<
      1 :: size(16),
    >>
  ) do
    before_exit(state)
    Process.exit(self(), :normal)
  end

  defp parse_packet(state, unknown_message) do
    Logger.debug("Unknown message: #{unknown_message}")
    before_exit(state)
    Process.exit(self(), :normal)
  end

  defp before_exit({_socket, ip, port, conn_id}) do
    Lobby.player_left(conn_id, ip, port)
  end
end
