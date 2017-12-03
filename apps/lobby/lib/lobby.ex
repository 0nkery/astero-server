require Logger

defmodule Lobby do
  use GenServer

  @lobby_port 11111

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, _socket} = :gen_udp.open(
      @lobby_port,
      [:binary, :inet6, {:ip, {0, 0, 0, 0, 0, 0, 0, 0}}, {:ipv6_v6only, true}]
    )
    Logger.info("Started #{__MODULE__} at port #{@lobby_port}")
    {:ok, %{}}
  end

  def handle_info({:udp, _socket, _ip, _port, data}, state) do

    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.puts(inspect(msg))
    {:noreply, state}
  end
end
