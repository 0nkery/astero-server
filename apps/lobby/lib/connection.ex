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
        Lobby.Connection.send(self(), {:heartbeat, Mmob.Heartbeat.new()})
        heartbeat_timer = schedule_heartbeat()

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
      {:send, data} ->
        encoded_packet = Mmob.Server.new(msg: data) |> Mmob.Server.encode()
        :gen_udp.send(player.socket, player.ip, player.port, encoded_packet)
        {:noreply, player}

      {:packet, packet} ->
        try do
          Mmob.Client.decode(packet)
        rescue
          FunctionClauseError ->
            notify = player.state == :joined
            close_connection(player, notify)

            {:noreply, player}
        else
          decoded ->

            player = handle(player, decoded)

            Process.cancel_timer(player.heartbeat_timer, async: true)
            heartbeat_timer = schedule_heartbeat()

            {:noreply, %{player | heartbeat_timer: heartbeat_timer, missed_heartbeats: 0}}
        end
    end
  end

  defp handle(%Player{state: state} = player, msg) do
    case msg do
      %Mmob.Client{msg: {:join, %Mmob.JoinGame{payload: payload}}} when state == :new ->

        Sector.player_joined(self(), player.conn_id, payload)

        heartbeat_timer = schedule_heartbeat()

        %{player | state: :joined, heartbeat_timer: heartbeat_timer}

      %Mmob.Client{msg: {:leave, %Mmob.LeaveGame{}}} when state == :joined ->
        close_connection(player)

        player

      %Mmob.Client{msg: {:heartbeat, %Mmob.Heartbeat{}}} -> player
      %Mmob.Client{msg: {:latency_measure, measure}} ->
        Lobby.Connection.send(self(), {:latency_measure, measure})

        player

      %Mmob.Client{msg: {:proxied, proxied_msg}} ->
        Sector.handle(proxied_msg, player.conn_id)

        player
    end
  end

  defp close_connection(player, notify \\ true) do
    if notify do
      Logger.debug("Player left: #{inspect(player.port)} #{player.conn_id}")
      Sector.player_left(self(), player.conn_id)
    end

    Process.exit(self(), :normal)
  end

  defp schedule_heartbeat() do
    Process.send_after(self(), :heartbeat, Application.get_env(:lobby, :heartbeat_interval))
  end
end
