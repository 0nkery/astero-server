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
    data = :gen_udp.recv(socket, 40, timeout)
    check_result = check.(data)

    cond do
      max_attempts == 0 -> false
      check_result == true -> true
      check_result == false -> recv_until(socket, max_attempts - 1, timeout, check)
    end
  end

  def connect(clients) do
    join = ClientMsg.join(clients.first.nickname)
    send_to_server(clients.first.socket, join)

    {:ok, {_, _, packet}} = :gen_udp.recv(clients.first.socket, 40)
    {:ack, first_id} = ServerMsg.parse(packet)

    join = ClientMsg.join(clients.second.nickname)
    send_to_server(clients.second.socket, join)

    {:ok, {_, _, packet}} = :gen_udp.recv(clients.second.socket, 40)
    {:ack, second_id} = ServerMsg.parse(packet)

    {first_id, second_id}
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
    :ok = Lobby.clean()

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
    {_first_id, second_id} = Helpers.connect(clients)

    {:ok, {_, _, packet}} = :gen_udp.recv(clients.first.socket, 40)
    {:joined, ^second_id, broadcasted_nickname} = ServerMsg.parse(packet)

    assert broadcasted_nickname == clients.second.nickname
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

    leave = ClientMsg.leave()
    Helpers.send_to_server(clients.second.socket, leave)

    {:ok, {_, _, packet}} = :gen_udp.recv(clients.first.socket, 40)
    {:left, ^second_id} = ServerMsg.parse(packet)
  end

  test "heartbeats", clients do
    {_first_id, second_id} = Helpers.connect(clients)

    _ = :gen_udp.recv(clients.first.socket, 40)

    heartbeat = ClientMsg.heartbeat()

    assert Helpers.recv_until(clients.first.socket, 10, 6000, fn data ->
      {:ok, {_, _, packet}} = data
      case ServerMsg.parse(packet) do
        {:heartbeat} ->
          Helpers.send_to_server(clients.first.socket, heartbeat)
          false
        {:left, ^second_id} -> true
        {:left, _} -> false
      end
    end)
  end
end
