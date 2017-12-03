require Logger

defmodule Lobby do
  use GenServer

  @port 11111
  @socket_options [:binary, :inet6, {:ip, {0, 0, 0, 0, 0, 0, 0, 0}}, {:ipv6_v6only, true}]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, _socket} = :gen_udp.open(@port, @socket_options)
    Logger.info("Started #{__MODULE__} at port #{@port}")
    {:ok, %{}}
  end

  def handle_info({:udp, socket, ip, port, data}, connections) do
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

  def handle_info(msg, state) do
    IO.puts(inspect(msg))
    {:noreply, state}
  end
end
