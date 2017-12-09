require Logger

defmodule Lobby.State do
  defstruct [
    connections: %{},
    conn_counter: 0
  ]
end

defmodule Lobby do
  use GenServer

  alias Lobby.State

  # Client

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

  # Server

  def init(:ok) do
    {:ok, %State{}}
  end

  def handle_cast({:packet, socket, ip, port, data}, lobby) do
    client = {ip, port}

    new_conn_id = unless Map.has_key?(lobby.connections, client) do
      lobby.conn_counter + 1
    else
      lobby.conn_counter
    end

    connections = Map.put_new_lazy(lobby.connections, client, fn ->
      {:ok, conn} = Lobby.ConnectionSupervisor.start_connection(socket, ip, port, lobby.conn_counter)

      conn
    end)

    conn = Map.get(connections, client)
    Lobby.Connection.process_packet(conn, data)

    {:noreply, %{lobby | conn_counter: new_conn_id, connections: connections}}
  end

  def handle_cast({:broadcast, packet, except}, lobby) do
    lobby.connections
      |> Enum.filter(fn {client, _conn} -> client != except end)
      |> do_broadcast(packet)

    {:noreply, lobby}
  end

  def handle_cast({:broadcast, packet, nil}, lobby) do
    do_broadcast(lobby.connections, packet)

    {:noreply, lobby}
  end

  def handle_cast({:player_left, conn_id, ip, port}, lobby) do
    {_conn, connections} = Map.pop(lobby.connections, {ip, port})
    player_left = Lobby.Msg.player_left(conn_id)
    Lobby.broadcast(player_left)

    {:noreply, %{lobby | connections: connections}}
  end

  defp do_broadcast(connections, packet) do
    Enum.each(connections, fn {_client, conn} -> Lobby.Connection.send(conn, packet) end)
  end
end
