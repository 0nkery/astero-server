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
    {:ok, player}
  end

  def handle_info(msg, %Player{missed_heartbeats: missed_heartbeats} = player) do
    max_missed_heartbeats = Application.get_env(:lobby, :max_missed_heartbeats)

    case msg do
      :heartbeat when missed_heartbeats >= max_missed_heartbeats ->
        Logger.debug("Player is not responding: #{inspect player}")
        {:noreply, close_connection(player)}

      :heartbeat ->
        Lobby.Connection.send(self(), Lobby.Msg.heartbeat())
        heartbeat_timer = schedule_ping()

        {:noreply,
          %{
            player |
            missed_heartbeats: player.missed_heartbeats + 1,
            heartbeat_timer: heartbeat_timer
          }
        }

      {:cancel_timer, _, _} -> {:noreply, player}
    end
  end

  def handle_cast(msg, player) do
    case msg do
      {:send, packet} ->
        :gen_udp.send(player.socket, player.ip, player.port, packet)
        {:noreply, player}

      {:packet, packet} ->
        player = parse_packet(player, packet)

        Process.cancel_timer(player.heartbeat_timer, async: true)
        heartbeat_timer = schedule_ping()

        {:noreply, %{player | heartbeat_timer: heartbeat_timer, missed_heartbeats: 0}}
    end
  end

  defp parse_packet(
     %Player{state: :new} = player,
     <<
       0 :: size(16),
       name_length :: size(8),
       nickname :: binary - size(name_length)
     >>
   ) do

    Logger.debug("Player joined: #{inspect(player.port)} #{player.conn_id} #{nickname}")

    ack = Lobby.Msg.ack(player.conn_id)
    Lobby.Connection.send(self(), ack)

    player_joined = Lobby.Msg.player_joined(player.conn_id, name_length, nickname)
    Lobby.broadcast(player_joined, {player.ip, player.port})

    heartbeat_timer = schedule_ping()

    %{player | state: :joined, heartbeat_timer: heartbeat_timer}
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
      Logger.debug("Player left: #{inspect(player.port)} #{player.conn_id}")
      Lobby.player_left(player.conn_id, player.ip, player.port)
    end

    Process.exit(self(), :normal)
  end

  defp schedule_ping() do
    Process.send_after(self(), :heartbeat, Application.get_env(:lobby, :heartbeat_interval))
  end
end
