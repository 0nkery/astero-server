require Logger

defmodule Lobby.Connection do
  use GenServer, restart: :transient

  def start_link(_opts, {socket, ip, port}) do
    conn_id = :rand.uniform(65536)
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
     <<0 :: size(16),
       name_length :: size(8),
       nickname :: binary - size(name_length)
     >>
   ) do

    Logger.debug("New player nickname: #{nickname}")

    ack = <<
      0 :: size(16),
      conn_id :: size(16)
    >>
    new_connection = <<
      1 :: size(16),
      conn_id :: size(16),
      name_length :: size(8),
      nickname :: binary - size(name_length)
    >>
    Lobby.Connection.send(self(), ack)
    Lobby.broadcast(new_connection, {ip, port})
  end

  defp parse_packet(_state, unknown_message) do
    Logger.debug("Unknown message: #{unknown_message}")
    Process.exit(self(), :normal)
  end
end
