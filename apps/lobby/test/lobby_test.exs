require Logger

defmodule LobbyTest.Helpers do
  @server_address {0, 0, 0, 0, 0, 0, 0, 1}
  @server_port 11111

  def send(socket, packet) do
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
    join = Lobby.Msg.Client.join(clients.first.nickname)
    LobbyTest.Helpers.send(clients.first.socket, join)

    {:ok, {_, _, <<0 :: size(16), first_id :: size(16)>>}} = :gen_udp.recv(clients.first.socket, 40)

    join = Lobby.Msg.Client.join(clients.second.nickname)
    LobbyTest.Helpers.send(clients.second.socket, join)

    {:ok, {_, _, <<0 :: size(16), second_id :: size(16)>>}} = :gen_udp.recv(clients.second.socket, 40)

    {first_id, second_id}
  end

  def skip_join_notification(socket, joined_player_id) do
    {:ok, {_, _, <<1 :: size(16), ^joined_player_id :: size(16), _ :: binary>>}} = :gen_udp.recv(socket, 40)
  end
end

defmodule LobbyTest do
  use ExUnit.Case

  alias LobbyTest.Helpers

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

    name_length = byte_size(clients.second.nickname)
    {:ok, {_, _,
      <<
        1 :: size(16),
        ^second_id :: size(16),
        5,
        broadcasted_nickname :: binary - size(name_length)
      >>
    }} = :gen_udp.recv(clients.first.socket, 40)

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

    leave = Lobby.Msg.Client.leave()
    Helpers.send(clients.second.socket, leave)

    {:ok, {_, _,
      <<
        2 :: size(16),
        ^second_id :: size(16)
      >>
    }} = :gen_udp.recv(clients.first.socket, 40)
  end

  test "heartbeats", clients do
    {_first_id, second_id} = Helpers.connect(clients)

    _ = :gen_udp.recv(clients.first.socket, 40)

    heartbeat = Lobby.Msg.Client.heartbeat()

    assert Helpers.recv_until(clients.first.socket, 10, 6000, fn data ->
      case data do
        {:ok, {_, _, <<3 :: size(16)>>}} ->
          Helpers.send(clients.first.socket, heartbeat)
          false
        {:ok, {_, _, <<2 :: size(16), ^second_id :: size(16)>>}} ->
          true
        {:ok, {_, _, <<2 :: size(16), _ :: size(16)>>}} ->
          false
      end
    end)
  end
end
