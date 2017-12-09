defmodule LobbyTest.Helpers do
  @server_address {0, 0, 0, 0, 0, 0, 0, 1}
  @server_port 11111

  def send(socket, packet) do
    :gen_udp.send(socket, @server_address, @server_port, packet)
  end
end

defmodule LobbyTest do
  use ExUnit.Case

  @socket_options [:binary, :inet6, {:active, false}]

  setup do
    {:ok, socket1} = :gen_udp.open(0, @socket_options)
    {:ok, socket2} = :gen_udp.open(0, @socket_options)

    on_exit fn ->
      leave = Lobby.Msg.Client.leave()
      LobbyTest.Helpers.send(socket1, leave)
      LobbyTest.Helpers.send(socket2, leave)
      :gen_udp.close(socket1)
      :gen_udp.close(socket2)
    end

    %{
      first: %{socket: socket1, nickname: "test1"},
      second: %{socket: socket2, nickname: "test2"},
    }
  end

  test "notifies other connections about the new one", clients do
    join = Lobby.Msg.Client.join(clients.first.nickname)
    LobbyTest.Helpers.send(clients.first.socket, join)

    {:ok, {_, _, <<0 :: size(16), _ :: binary>>}} = :gen_udp.recv(clients.first.socket, 40)

    join = Lobby.Msg.Client.join(clients.second.nickname)
    LobbyTest.Helpers.send(clients.second.socket, join)

    name_length = byte_size(clients.second.nickname)
    {:ok, {_, _, <<0 :: size(16), id :: size(16)>>}} = :gen_udp.recv(clients.second.socket, 40)
    {:ok, {_, _,
      <<
        1 :: size(16),
        broadcasted_id :: size(16),
        5,
        broadcasted_nickname :: binary - size(name_length)
      >>
    }} = :gen_udp.recv(clients.first.socket, 40)

    assert broadcasted_id == id
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
      {:DOWN, ^ref, :process, ^conn, :normal} -> assert true
      _ -> assert false
    end
  end

  test "notifies other players when player left", clients do
    join = Lobby.Msg.Client.join(clients.first.nickname)
    LobbyTest.Helpers.send(clients.first.socket, join)
    _ = :gen_udp.recv(clients.first.socket, 40)

    join = Lobby.Msg.Client.join(clients.second.nickname)
    LobbyTest.Helpers.send(clients.second.socket, join)

    _ = :gen_udp.recv(clients.first.socket, 40)

    {:ok, {_, _,
      <<
        0 :: size(16),
        id :: size(16)
      >>
    }} = :gen_udp.recv(clients.second.socket, 40)

    leave = Lobby.Msg.Client.leave()
    LobbyTest.Helpers.send(clients.second.socket, leave)

    {:ok, {_, _,
      <<
        2 :: size(16),
        broadcasted_id :: size(16)
      >>
    }} = :gen_udp.recv(clients.first.socket, 40)

    assert broadcasted_id == id
  end
end
