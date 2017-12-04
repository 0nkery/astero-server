require Logger

defmodule Lobby do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_packet(socket, ip, port, data) do
    GenServer.cast(Lobby, {:packet, socket, ip, port, data})
  end

  def broadcast(packet, except) do
    GenServer.cast(Lobby, {:broadcast, packet, except})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast({:packet, socket, ip, port, data}, connections) do
    client = {ip, port}

    connections = Map.put_new_lazy(connections, client, fn ->
      {:ok, conn} = Lobby.ConnectionSupervisor.start_connection(socket, ip, port)
      conn
    end)

    connections
    |> Map.get(client)
    |> Lobby.Connection.process_packet(data)

    {:noreply, connections}
  end

  def handle_cast({:broadcast, packet, {ip, port} = except}, connections) do
    connections
      |> Enum.filter(fn {{i, p}, _conn} -> i != ip and p != port end)
      |> Enum.each(fn {_client, conn} -> Lobby.Connection.send(conn, packet) end)
  end
end
