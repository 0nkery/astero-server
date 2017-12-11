require Logger

defmodule Lobby.Connection.Player do
  @enforce_keys [:socket, :ip, :port, :conn_id]

  defstruct [
    :socket,
    :ip,
    :port,
    :conn_id,
    state: :new, # OR :joined
    missed_heartbeats: 0,
    heartbeat_timer: nil
  ]
end

defmodule Lobby.Connection do
  use GenServer, restart: :transient

  alias Lobby.Connection.Player

  # Client

  def start_link(_opts, {socket, ip, port, conn_id}) do
    GenServer.start_link(__MODULE__, %Player{
      socket: socket,
      ip: ip,
      port: port,
      conn_id: conn_id
    })
  end

  def handle_packet(conn, packet) do
    GenServer.cast(conn, {:packet, packet})
  end

  def send(conn, packet) do
    GenServer.cast(conn, {:send, packet})
  end

  # Server

  def init(%Player{} = player) do
    Logger.debug("Player joined: #{inspect(player.ip)} #{inspect(player.port)} #{player.conn_id}")

    heartbeat_timer = Process.send_after(self(), :heartbeat, 5000)

    {:ok, %{player | heartbeat_timer: heartbeat_timer}}
  end

  def handle_info(:heartbeat, %Player{missed_heartbeats: missed_heartbeats} = player)
    when missed_heartbeats >= 4
  do
    close_connection(player)
  end

  def handle_info(:heartbeat, player) do
    Lobby.Connection.send(self(), Lobby.Msg.heartbeat())
    heartbeat_timer = Process.send_after(self(), :heartbeat, 5000)

    {:noreply,
      %{
        player |
          missed_heartbeats: player.missed_heartbeats + 1,
          heartbeat_timer: heartbeat_timer
      }
    }
  end

  def handle_info({:cancel_timer, _, _}, player), do: {:noreply, player}

  def handle_cast({:send, packet}, player) do
    :gen_udp.send(player.socket, player.ip, player.port, packet)
    {:noreply, player}
  end

  def handle_cast({:packet, packet}, player) do
    player = parse_packet(player, packet)

    Process.cancel_timer(player.heartbeat_timer, async: true)
    heartbeat_timer = Process.send_after(self(), :ping, 5000)

    {:noreply, %{player | heartbeat_timer: heartbeat_timer, missed_heartbeats: 0}}
  end

  defp parse_packet(
     %Player{state: :new} = player,
     <<
       0 :: size(16),
       name_length :: size(8),
       nickname :: binary - size(name_length)
     >>
   ) do

    Logger.debug("New player nickname: #{nickname}")

    ack = Lobby.Msg.ack(player.conn_id)
    Lobby.Connection.send(self(), ack)

    player_joined = Lobby.Msg.player_joined(player.conn_id, name_length, nickname)
    Lobby.broadcast(player_joined, {player.ip, player.port})

    %{player | state: :joined}
  end

  defp parse_packet(
    %Player{state: :joined} = player,
    <<
      1 :: size(16),
    >>
  ) do
    close_connection(player)

    player
  end

  defp parse_packet(player, <<2 :: size(16)>>), do: player

  defp parse_packet(%Player{state: state} = player, _unknown_msg) do
    notify = case state do
      :new -> false
      :joined -> true
    end

    close_connection(player, notify)

    player
  end

  defp close_connection(player, notify \\ true) do
    if notify do
      Logger.debug("Player left: #{inspect(player.ip)}, #{inspect(player.port)}, #{player.conn_id}")
      Lobby.player_left(player.conn_id, player.ip, player.port)
    end

    Process.exit(self(), :normal)
  end
end
