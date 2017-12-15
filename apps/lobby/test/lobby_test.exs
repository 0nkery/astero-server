require Logger

defmodule LobbyTest.Helpers.ClientMsg do
  def join(nickname) do
    name_length = byte_size(nickname)
    <<
      0 :: size(16),
      name_length,
      nickname :: binary - size(name_length)
    >>
  end

  def leave() do
    <<
      1 :: size(16)
    >>
  end

  def heartbeat() do
    <<
      2 :: size(16)
    >>
  end
end

defmodule LobbyTest.Helpers.ServerMsg do
  def parse(<<
    0 :: size(16),
    id :: size(16),
    _ :: binary
  >>) do
    {:ack, id}
  end

  def parse(<<
    1 :: size(16),
    id :: size(16),
    name_len :: size(8),
    nickname :: binary - size(name_len),
    _ :: binary
  >>) do
    {:joined, id, nickname}
  end

  def parse(<<2 :: size(16), id :: size(16)>>), do: {:left, id}

  def parse(<<3 :: size(16)>>), do: {:heartbeat}
end

defmodule LobbyTest.Helpers do
  @server_address {0, 0, 0, 0, 0, 0, 0, 1}
  @server_port 11111

  alias LobbyTest.Helpers.ClientMsg
  alias LobbyTest.Helpers.ServerMsg

  def send_to_server(socket, packet) do
    :gen_udp.send(socket, @server_address, @server_port, packet)
  end

  def recv_until(socket, max_attempts, timeout, check) do
    {:ok, {_, _, packet}} = :gen_udp.recv(socket, 40, timeout)
    data = ServerMsg.parse(packet)
    check_result = check.(data)

    case check_result do
      _ when max_attempts == 0 -> false
      true -> true
      {true, data} -> {true, data}
      false -> recv_until(socket, max_attempts - 1, timeout, check)
    end
  end

  def connect(clients) do
    join = ClientMsg.join(clients.first.nickname)
    send_to_server(clients.first.socket, join)

    {true, first_id} = recv_until(clients.first.socket, 5, 500, fn data ->
      case data do
        {:ack, first_id} -> {true, first_id}
        _ -> false
      end
    end)

    join = ClientMsg.join(clients.second.nickname)
    send_to_server(clients.second.socket, join)

    {:ok, {_, _, packet}} = :gen_udp.recv(clients.second.socket, 40)
    {:ack, second_id} = ServerMsg.parse(packet)

    {first_id, second_id}
  end

  def disconnect(client) do
    leave = ClientMsg.leave()
    send_to_server(client.socket, leave)
  end

  def skip_join_notification(socket, joined_player_id) do
    {:ok, {_, _, <<1 :: size(16), ^joined_player_id :: size(16), _ :: binary>>}} = :gen_udp.recv(socket, 40)
  end
end

defmodule LobbyTest do
  use ExUnit.Case

  alias LobbyTest.Helpers
  alias LobbyTest.Helpers.ClientMsg
  alias LobbyTest.Helpers.ServerMsg

  @socket_options [:binary, :inet6, {:active, false}]

  setup do
    {:ok, socket1} = :gen_udp.open(0, @socket_options)
    {:ok, socket2} = :gen_udp.open(0, @socket_options)

    clients = %{
      first: %{socket: socket1, nickname: "test1"},
      second: %{socket: socket2, nickname: "test2"},
    }

    on_exit fn ->
      :gen_udp.close(socket1)
      :gen_udp.close(socket2)
    end

    clients
  end

  test "notifies other connections about the new one", clients do
    {first_id, second_id} = Helpers.connect(clients)

    assert Helpers.recv_until(clients.first.socket, 5, 500, fn data ->
      case data do
        {:joined, ^second_id, broadcasted_nickname} ->
          assert broadcasted_nickname == clients.second.nickname
          true
        _ -> false
      end
    end)

    Helpers.disconnect(clients.first)
    Helpers.disconnect(clients.second)
  end

  test "closes on unknown messages", clients do
    {:ok, conn} = Lobby.ConnectionSupervisor.start_connection(
      clients.first.socket,
      {0, 0, 0, 0, 0, 0, 0, 1}, 60000,
      100
    )
    ref = Process.monitor(conn)

    packet = "test"
    Lobby.Connection.handle_packet(conn, packet)

    receive do
      {:DOWN, got_ref, :process, got_conn, :normal} ->
        assert got_ref == ref
        assert got_conn == conn

      _ -> assert false
    end
  end

  test "notifies other players when player left", clients do
    {_first_id, second_id} = Helpers.connect(clients)

    Helpers.skip_join_notification(clients.first.socket, second_id)

    Helpers.disconnect(clients.second)

    {:ok, {_, _, packet}} = :gen_udp.recv(clients.first.socket, 40)
    {:left, ^second_id} = ServerMsg.parse(packet)

    Helpers.disconnect(clients.first)
  end

  test "heartbeats", clients do
    {_first_id, second_id} = Helpers.connect(clients)

    _ = :gen_udp.recv(clients.first.socket, 40)

    heartbeat = ClientMsg.heartbeat()

    assert Helpers.recv_until(clients.first.socket, 10, 6000, fn data ->
      case data do
        {:heartbeat} ->
          Helpers.send_to_server(clients.first.socket, heartbeat)
          false
        {:left, ^second_id} -> true
        {:left, _} -> false
      end
    end)

    Helpers.disconnect(clients.first)
  end
end
