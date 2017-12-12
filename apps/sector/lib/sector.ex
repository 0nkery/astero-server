require Logger

defmodule Sector.State do
  defstruct players: %{}
end

defmodule Sector do
  use GenServer

  alias Sector.State

  # Client
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  # Server
  def init(:ok) do
    Logger.info("Started #{__MODULE__}")
    {:ok, %State{}}
  end
end
