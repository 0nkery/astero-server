require Logger

defmodule Lobby.UDP do
  use GenServer

  @port 11111
  @socket_options [:binary, :inet6, {:ip, {0, 0, 0, 0, 0, 0, 0, 0}}, {:ipv6_v6only, true}]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, _socket} = :gen_udp.open(@port, @socket_options)
    Logger.info("Started #{__MODULE__} at port #{@port}")
    {:ok, {}}
  end

  def handle_info({:udp, socket, ip, port, data}, _state) do
    Lobby.handle_packet(socket, ip, port, data)
    {:noreply, _state}
  end

  def handle_info(msg, state) do
    IO.puts(inspect(msg))
    {:noreply, state}
  end
end