require Logger

defmodule Sector do
  use GenServer

  alias Astero.JoinAck
  alias Astero.OtherJoined
  alias Astero.OtherLeft
  alias Astero.Asteroids
  alias Astero.Spawn
  alias Astero.Asteroid
  alias Astero.SimUpdates
  alias Astero.SimUpdate
  alias Astero.Entity
  alias Astero.OtherInput
  alias Astero.LatencyMeasure
  alias Astero.Shots
  alias Astero.GameplayEvents

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

  def player_joined(conn, player_id, nickname) do
    GenServer.cast(Sector, {:joined, conn, player_id, nickname})
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

    asteroids = Asteroid.Impl.create_asteroids(@initial_asteroids_count, 100.0, 250.0)
    asteroids = Map.new(Enum.zip(1..@initial_asteroids_count, asteroids))

    Process.send_after(self(), :spawn, @asteroid_spawn_rate)
    Process.send_after(self(), :update_sim, @simulation_update_rate)
    Process.send_after(self(), :update_latencies, 10000)

    {:ok, %State{asteroids: asteroids}}
  end

  def handle_cast(msg, sector) do
    case msg do
      {:joined, conn, player_id, nickname} ->
        player = Player.random(conn, nickname, @world_bounds)
        send_ack(conn, player_id, player)

        joined = OtherJoined.new(id: player_id, nickname: nickname, body: player.body)
        Lobby.broadcast({:other_joined, joined}, conn)

        Enum.each(sector.players, fn {id, player} ->
          older_player = OtherJoined.new(id: id, nickname: player.nickname, body: player.body)
          Lobby.Connection.send(conn, {:other_joined, older_player})
        end)

        asteroids = Asteroids.new(entities: sector.asteroids)
        spawn_asteroids = Spawn.new(entity: {:asteroids, asteroids})
        Lobby.Connection.send(conn, {:spawn, spawn_asteroids})

        {:noreply, %{sector | players: Map.put(sector.players, player_id, player)}}

      {:left, conn, player_id} ->
        player_left = OtherLeft.new(id: player_id)
        Lobby.broadcast({:other_left, player_left}, conn)

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
          asteroid = Asteroid.Impl.create_asteroid(100.0, 300.0)

          asteroids = Asteroids.new(entities: %{new_id => asteroid})
          spawn_asteroids = Spawn.new(entity: {:asteroids, asteroids})
          Lobby.broadcast({:spawn, spawn_asteroids})

          Process.send_after(self(), :spawn, @asteroid_spawn_rate)

          %{sector | asteroids: Map.put(sector.asteroids, new_id, asteroid)}
        end

        {:noreply, sector}

      :update_sim ->
        {sector, new_shots, events} = State.update(sector, @simulation_update_rate / 1000.0, @world_bounds)

        Process.send_after(self(), :update_sim, @simulation_update_rate)

        send_sim_updates(sector)

        cur_shot_count = Enum.count(sector.shots)
        new_shots_count = Enum.count(new_shots)

        shots = if new_shots_count > 0 do
          shot_count = cur_shot_count + new_shots_count

          new_shots = Map.new(Enum.zip(cur_shot_count..shot_count, new_shots))

          spawn_shots = Spawn.new(entity: {:shots, Shots.new(entities: new_shots)})
          Lobby.broadcast({:spawn, spawn_shots})

          Map.merge(sector.shots, new_shots)
        else
          sector.shots
        end

        if Enum.count(events) do
          Lobby.broadcast({:gameplay_events, GameplayEvents.new(events: events)})
        end

        {:noreply, %{sector | shots: shots}}

      :update_latencies ->
        latency = LatencyMeasure.new(timestamp: System.system_time(:milliseconds))
        Lobby.broadcast({:latency, latency})
        Process.send_after(self(), :update_latencies, 10000)

        {:noreply, sector}
    end
  end

  defp handle_msg(sector, msg, player_id) do
    case msg do
      {:input, input} ->
        {_old, players} = Map.get_and_update(sector.players, player_id, fn player ->
          updated = player
          |> Player.update_input(input, @world_bounds)

          Lobby.broadcast({:other_input, OtherInput.new(id: player_id, input: updated.input)}, player.conn)

          {player, updated}
        end)

        %{sector | players: players}

      {:latency, %LatencyMeasure{timestamp: timestamp}} ->
        {_old, players} = Map.get_and_update(sector.players, player_id, fn player ->
          updated = Player.update_latency(player, timestamp)

          {player, updated}
        end)

        %{sector | players: players}
    end
  end

  defp send_ack(conn, player_id, player) do
    latency_measure = LatencyMeasure.new(timestamp: System.system_time(:milliseconds))
    join_ack = JoinAck.new(body: player.body, id: player_id, latency: latency_measure)

    Lobby.Connection.send(conn, {:join_ack, join_ack})
  end

  defp send_sim_updates(sector) do
    Task.start(fn ->
      asteroid_updates = Enum.map(sector.asteroids, fn {id, asteroid} ->
        SimUpdate.new(
          entity: Entity.value(:ASTEROID),
          id: id,
          body: %{asteroid.body | size: nil},
        )
      end)

      Enum.each(sector.players, fn {_id, player} ->
        updates = Enum.map(asteroid_updates, fn update ->
          body = State.update_body(update.body, player.latency / 1000.0)

          %{update | body: body}
        end)
        Lobby.Connection.send(player.conn, {:sim_updates, SimUpdates.new(updates: updates)})
      end)
    end)

    Task.start(fn ->
      player_updates = Enum.map(sector.players, fn {id, player} ->
        SimUpdate.new(
          entity: Entity.value(:PLAYER),
          id: id,
          body: %{player.body | size: nil, rvel: nil}
        )
      end)

      Enum.each(sector.players, fn {_id, player} ->
        updates = Enum.map(player_updates, fn update ->
          body = State.update_body(update.body, player.latency / 1000.0)

          %{update | body: body}
        end)
        Lobby.Connection.send(player.conn, {:sim_updates, SimUpdates.new(updates: updates)})
      end)
    end)
  end
end
