require Logger

defmodule LobbyTest.Helpers do
  @server_address {0, 0, 0, 0, 0, 0, 0, 1}
  @server_port 11111

  alias Astero.Server
  alias Astero.Client
  alias Astero.Join
  alias Astero.JoinAck
  alias Astero.Leave

  def send_to_server(socket, data) do
    packet = Client.new(msg: data) |> Client.encode()
    :gen_udp.send(socket, @server_address, @server_port, packet)
  end

  def recv_until(socket, check) do
    {:ok, {_, _, packet}} = :gen_udp.recv(socket, 40, 500)
    %Server{msg: data} = Server.decode(packet)
    check_result = check.(data)

    case check_result do
      true -> true
      {true, data} -> {true, data}

      false -> recv_until(socket, check)
    end
  end

  def connect(clients) do
    join = {:join, Join.new(nickname: clients.first.nickname)}
    send_to_server(clients.first.socket, join)

    {true, first_id} = recv_until(clients.first.socket, fn data ->
      case data do
        {:join_ack, %JoinAck{id: first_id}} -> {true, first_id}
        _ -> false
      end
    end)

    join = {:join, Join.new(nickname: clients.second.nickname)}
    send_to_server(clients.second.socket, join)

    {true, second_id} = recv_until(clients.second.socket, fn data ->
      case data do
        {:join_ack, %JoinAck{id: second_id}} -> {true, second_id}
        _ -> false
      end
    end)

    {first_id, second_id}
  end

  def disconnect(client) do
    leave = {:leave, Leave.new()}
    send_to_server(client.socket, leave)
  end
end

defmodule LobbyTest do
  use ExUnit.Case

  alias LobbyTest.Helpers

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

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:other_joined, %Astero.OtherJoined{id: ^second_id, nickname: broadcasted_nickname}} ->
          assert broadcasted_nickname == clients.second.nickname
          true

        _ -> false
      end
    end)

    assert Helpers.recv_until(clients.second.socket, fn data ->
      case data do
        {:other_joined, %Astero.OtherJoined{id: ^first_id, nickname: broadcasted_nickname}} ->
            assert broadcasted_nickname == clients.first.nickname
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

    Helpers.disconnect(clients.second)

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:other_left, %Astero.OtherLeft{id: ^second_id}} -> true

        _ -> false
      end
    end)

    Helpers.disconnect(clients.first)
  end

  test "heartbeats", clients do
    {_first_id, second_id} = Helpers.connect(clients)

    heartbeat = {:heartbeat, Astero.Heartbeat.new()}

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:heartbeat, %Astero.Heartbeat{}} ->
          Helpers.send_to_server(clients.first.socket, heartbeat)
          false

        {:other_left, %Astero.OtherLeft{id: ^second_id}} -> true
        _ -> false
      end
    end)

    Helpers.disconnect(clients.first)
  end

  test "sending asteroid data to newly connected players", clients do
    {_, _} = Helpers.connect(clients)

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:spawn, %Astero.Spawn{entity: {:asteroids, asteroids}}} ->
          assert Enum.count(asteroids.entities) == 5
          true
        _ -> false
      end
    end)
  end

  test "broadcasting input events", clients do
    {_first_id, second_id} = Helpers.connect(clients)

    turn_dir = -1
    turn = {:input, Astero.Input.new(turn: turn_dir)}
    Helpers.send_to_server(clients.second.socket, turn)

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:other_input, %Astero.OtherInput{id: ^second_id, input: input}} ->
          assert input.turn == turn_dir
          true
        _ -> false
      end
    end)

    accel_dir = 1
    accel = {:input, Astero.Input.new(accel: accel_dir)}
    Helpers.send_to_server(clients.second.socket, accel)

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:other_input, %Astero.OtherInput{id: ^second_id, input: input}} ->
          assert input.accel == accel_dir
          true
        _ -> false
      end
    end)
  end

  test "broadcasting simulation data", clients do
    {_, _} = Helpers.connect(clients)

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:sim_updates, sim_updates} ->
          Enum.any?(sim_updates.updates, fn upd ->
            upd.entity == Astero.Entity.value(:ASTEROID)
          end)

        _ -> false
      end
    end)

    assert Helpers.recv_until(clients.first.socket, fn data ->
      case data do
        {:sim_updates, sim_updates} ->
          Enum.any?(sim_updates.updates, fn upd ->
            upd.entity == Astero.Entity.value(:PLAYER)
          end)

        _ -> false
      end
    end)
  end
end
