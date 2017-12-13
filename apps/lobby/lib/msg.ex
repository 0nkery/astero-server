defmodule Lobby.Msg do
  def ack(conn_id) do
    <<
      0 :: size(16),
      conn_id :: size(16)
    >>
  end

  def player_joined(conn_id, nickname) do
    nickname_len = byte_size(nickname)
    <<
      1 :: size(16),
      conn_id :: size(16),
      nickname_len :: size(8),
      nickname :: binary - size(nickname_len)
    >>
  end

  def player_left(conn_id) do
    <<
      2 :: size(16),
      conn_id :: size(16)
    >>
  end

  def heartbeat() do
    <<
      3 :: size(16)
    >>
  end
end

defmodule Lobby.Msg.Incoming do
  def parse(<<
    0 :: size(16),
    name_length :: size(8),
    nickname :: binary - size(name_length)
  >>) do
    {:join, nickname}
  end

  def parse(<<1 :: size(16)>>) do
    {:leave}
  end

  def parse(<<2 :: size(16)>>) do
    {:heartbeat}
  end

  def parse(_unknown), do: {:unknown}
end

defmodule Lobby.Msg.Client do
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