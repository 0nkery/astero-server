require Logger

defmodule Lobby do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_packet(socket, ip, port, data) do
    GenServer.cast(Lobby, {:packet, socket, ip, port, data})
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
end
