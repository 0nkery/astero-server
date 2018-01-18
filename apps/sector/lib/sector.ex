require Logger

defmodule Sector do
  use GenServer

  alias Sector.State
  alias Sector.Player

  @initial_asteroids_count 5
  @max_asteroids_count 10
  @asteroid_spawn_rate 5000
  @simulation_update_rate 33
  @world_bounds {400, 300}

  # Client
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def player_joined(conn, player_id, payload) do
    GenServer.cast(Sector, {:joined, conn, player_id, payload})
  end

  def player_left(conn, player_id) do
    GenServer.cast(Sector, {:left, conn, player_id})
  end

  def handle(msg, player_id) do
    GenServer.cast(Sector, {:handle, msg, player_id})
  end

  # Server
  def init(:ok) do
    Logger.info("Started #{__MODULE__}")

    asteroids = Astero.Asteroid.Impl.create_asteroids(@initial_asteroids_count, 100.0, 250.0)
    asteroids = Enum.map(Enum.zip(1..@initial_asteroids_count, asteroids), fn {id, asteroid} ->
      %{asteroid | id: id}
    end)

    Process.send_after(self(), :spawn, @asteroid_spawn_rate)
    Process.send_after(self(), :update_sim, @simulation_update_rate)

    {:ok, %State{asteroids: asteroids}}
  end

  def handle_cast(msg, sector) do
    case msg do
      {:joined, conn, player_id, payload} ->
        nickname = Astero.JoinPayload.decode(payload).nickname
        Logger.debug("Player joined: #{player_id} #{nickname}")

        player = Player.random(conn, nickname, @world_bounds)
        send_ack(conn, player_id, player)

        other = Astero.Player.new(id: player_id, nickname: nickname, body: player.body)
        joined = Astero.Create.new(entity: {:player, other})
        broadcast_msg({:create, joined}, conn)

        Enum.each(sector.players, fn {id, player} ->
          older_player = Astero.Player.new(id: id, body: player.body, nickname: player.nickname)
          send_msg(conn, {:create, Astero.Create.new(entity: {:player, older_player})})
        end)

        Enum.each(sector.asteroids, fn asteroid ->
          send_msg(conn, {:create, Astero.Create.new(entity: {:asteroid, asteroid})})
        end)

        {:noreply, %{sector | players: Map.put(sector.players, player_id, player)}}

      {:left, _conn, player_id} ->
        player_left = Astero.Destroy.new(id: player_id, entity: Astero.Entity.value(:PLAYER))
        broadcast_msg({:destroy, player_left})

        {_player, players} = Map.pop(sector.players, player_id)

        {:noreply, %{sector | players: players}}

      {:handle, msg, player_id} ->
        sector = handle_msg(sector, msg, player_id)

        {:noreply, sector}
    end
  end

  def handle_info(msg, sector) do
    case msg do
      :spawn ->
        asteroids_count = Enum.count(sector.asteroids)

        sector = if asteroids_count == @max_asteroids_count do
          sector
        else
          new_id = asteroids_count + 1
          asteroid = Astero.Asteroid.Impl.create_asteroid(100.0, 300.0)
          asteroid = %{asteroid | id: new_id}
          broadcast_msg({:create, Astero.Create.new(entity: {:asteroid, asteroid})})

          Process.send_after(self(), :spawn, @asteroid_spawn_rate)

          %{sector | asteroids: [asteroid | sector.asteroids]}
        end

        {:noreply, sector}

      :update_sim ->
        {sector, _new_shots} = State.update(sector, @simulation_update_rate / 1000.0, @world_bounds)

        Process.send_after(self(), :update_sim, @simulation_update_rate)

        send_sim_updates(sector)

        {:noreply, sector}
    end
  end

  defp handle_msg(sector, msg, player_id) do
    case msg do
      {:input, input} ->
        {_old, players} = Map.get_and_update(sector.players, player_id, fn player ->
          updated = player
          |> Player.update_input(input, @world_bounds)
          {player, updated}
        end)

        %{sector | players: players}
    end
  end

  defp send_msg(conn, msg) do
    msg = Astero.Server.new(msg: msg) |> Astero.Server.encode()
    Lobby.Connection.send(conn, {:proxied, Mmob.Proxied.new(msg: msg)})
  end

  defp broadcast_msg(msg, except \\ nil) do
    msg = Astero.Server.new(msg: msg) |> Astero.Server.encode()
    Lobby.broadcast({:proxied, Mmob.Proxied.new(msg: msg)}, except)
  end

  defp send_ack(conn, player_id, player) do
    payload = Astero.Player.new(body: player.body, id: player_id) |> Astero.Player.encode()
    Lobby.Connection.send(conn, {:join_ack, Mmob.JoinAck.new(payload: payload)})
  end

  defp send_sim_updates(sector) do
    Task.start(fn ->
      asteroid_updates = Enum.map(sector.asteroids, fn asteroid ->
        Astero.Update.new(entity: {:asteroid, %{asteroid | body: %{asteroid.body | size: nil}}})
      end)

      Enum.each(sector.players, fn {_id, player} ->
        send_msg(player.conn, {:list, Astero.UpdateList.new(update_list: asteroid_updates)})
      end)
    end)

    Task.start(fn ->
      player_updates = Enum.map(sector.players, fn {id, player} ->
        player_update = Astero.Player.new(
          id: id,
          body: %{player.body | size: nil, rvel: nil}
        )
        Astero.Update.new(entity: {:player, player_update})
      end)

      Enum.each(sector.players, fn {_id, player} ->
        send_msg(player.conn, {:list, Astero.UpdateList.new(update_list: player_updates)})
      end)
    end)
  end
end
