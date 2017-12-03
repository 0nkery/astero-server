require Logger

defmodule Lobby.Connection do
  use GenServer, restart: :temporary

  def start_link(_opts, state) do
    GenServer.start_link(__MODULE__, state)
  end

  def process_packet(conn, data) do
    GenServer.cast(conn, {:packet, data})
  end

  def init({_socket, ip, port} = state) do
    Logger.info("Got new connection: #{inspect(ip)} #{inspect(port)}")
    {:ok, state}
  end

  def handle_cast({:packet, data}, {socket, ip, port} = state) do
    :gen_udp.send(socket, ip, port, data)
    {:noreply, state}
  end
end