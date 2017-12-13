require Logger

defmodule Lobby.State do
  defstruct [
    connections: %{},
    refs: %{},
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

  # for testing purposes
  def clean() do
    GenServer.call(Lobby, :clean)
  end

  # Server

  def init(:ok) do
    Logger.info("Started #{__MODULE__}")
    {:ok, %State{}}
  end

  def handle_call(:clean, _from, _lobby) do
    {:reply, :ok, %State{}}
  end

  def handle_cast({:packet, socket, ip, port, data}, lobby) do
    client = {ip, port}

    {lobby, conn} = unless Map.has_key?(lobby.connections, client) do
      {:ok, conn} = Lobby.ConnectionSupervisor.start_connection(socket, ip, port, lobby.conn_counter)
      ref = Process.monitor(conn)

      {
        %{
          lobby |
            conn_counter: lobby.conn_counter + 1,
            connections: Map.put(lobby.connections, client, conn),
            refs: Map.put(lobby.refs, ref, client)
        },
        conn
      }
    else
      {lobby, Map.get(lobby.connections, client)}
    end

    Lobby.Connection.handle_packet(conn, data)

    {:noreply, lobby}
  end

  def handle_cast({:broadcast, packet, except}, lobby) do
    lobby.connections
      |> Enum.filter(fn {_client, conn} -> conn != except end)
      |> Enum.each(fn {_client, conn} -> Lobby.Connection.send(conn, packet) end)

    {:noreply, lobby}
  end

  def handle_info(msg, lobby) do
    case msg do
      {:DOWN, ref, :process, _pid, :normal} ->
        {client, refs} = Map.pop(lobby.refs, ref)
        {_conn, connections} = Map.pop(lobby.connections, client)

        {:noreply, %{lobby | refs: refs, connections: connections}}

      {:DOWN, _, _, _, _} -> {:noreply, lobby}
    end
  end
end
