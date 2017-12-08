require Logger

defmodule Lobby do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_packet(socket, ip, port, data) do
    GenServer.cast(Lobby, {:packet, socket, ip, port, data})
  end

  def broadcast(packet, except \\ nil) do
    GenServer.cast(Lobby, {:broadcast, packet, except})
  end

  def player_left(conn_id, ip, port) do
    GenServer.cast(Lobby, {:player_left, conn_id, ip, port})
  end

  def init(:ok) do
    {:ok, {%{}, 0}}
  end

  def handle_cast({:packet, socket, ip, port, data}, {connections, cur_conn_id}) do
    client = {ip, port}

    new_conn_id = unless Map.has_key?(connections, client) do
      cur_conn_id + 1
    end

    connections = Map.put_new_lazy(connections, client, fn ->
      {:ok, conn} = Lobby.ConnectionSupervisor.start_connection(socket, ip, port, cur_conn_id)
      conn
    end)

    connections
    |> Map.get(client)
    |> Lobby.Connection.process_packet(data)

    {:noreply, {connections, new_conn_id}}
  end

  def handle_cast({:broadcast, packet, except}, {connections, cur_conn_id}) do
    connections
      |> Enum.filter(fn {client, _conn} -> client != except end)
      |> do_broadcast(packet)

    {:noreply, {connections, cur_conn_id}}
  end

  def handle_cast({:broadcast, packet, nil}, {connections, cur_conn_id}) do
    do_broadcast(connections, packet)

    {:noreply, {connections, cur_conn_id}}
  end

  def handle_cast({:player_left, conn_id, ip, port}, {connections, cur_conn_id}) do
    {_conn, connections} = Map.pop(connections, {ip, port})
    player_left = Lobby.Msg.player_left(conn_id)
    Lobby.broadcast(player_left)

    {:noreply, {connections, cur_conn_id}}
  end

  defp do_broadcast(connections, packet) do
    Enum.each(connections, fn {_client, conn} -> Lobby.Connection.send(conn, packet) end)
  end
end
