defmodule Lobby.ConnectionSupervisor do
  use Supervisor

  @name Lobby.ConnectionSupervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: @name)
  end

  def start_connection(socket, ip, port, conn_id) do
    Supervisor.start_child(@name, [{socket, ip, port, conn_id}])
  end

  def init(_args) do
    Supervisor.init([Lobby.Connection], strategy: :simple_one_for_one)
  end
end