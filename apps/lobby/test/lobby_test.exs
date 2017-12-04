defmodule LobbyTest do
  use ExUnit.Case

  @socket_options [:binary, :inet6, {:active, false}]
  @server_address {0, 0, 0, 0, 0, 0, 0, 0}
  @server_port 11111

  setup do
    {:ok, socket1} = :gen_udp.open(0, @socket_options)
    {:ok, socket2} = :gen_udp.open(0, @socket_options)
    %{
      first: %{socket: socket1, nickname: "test1"},
      second: %{socket: socket2, nickname: "test2"},
    }
  end

  test "notifies other connections about the new one", clients do
    name_length = byte_size(clients.first.nickname)
    hello_packet = <<0 :: size(16), name_length, clients.first.nickname :: binary - size(name_length)>>
    :gen_udp.send(clients.first.socket, @server_address, @server_port, hello_packet)

    {:ok, {_, _, <<0 :: size(16), _ :: binary>>}} = :gen_udp.recv(clients.first.socket, 40)

    name_length = byte_size(clients.second.nickname)
    hello_packet = <<0 :: size(16), name_length, clients.second.nickname :: binary - size(name_length)>>
    :gen_udp.send(clients.second.socket, @server_address, @server_port, hello_packet)

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
    running_processes = Supervisor.which_children(Lobby.ConnectionSupervisor)
    Enum.each(running_processes, fn {_id, child, _type, _modules} ->
      Supervisor.terminate_child(Lobby.ConnectionSupervisor, child)
    end)

    packet = "test"
    :gen_udp.send(clients.first.socket, @server_address, @server_port, packet)

    data = Supervisor.count_children(Lobby.ConnectionSupervisor)
    assert data.active == 0
  end
end
