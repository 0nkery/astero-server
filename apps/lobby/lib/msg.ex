defmodule Lobby.Msg do
  def ack(conn_id) do
    <<
      0 :: size(16),
      conn_id :: size(16)
    >>
  end

  def player_joined(conn_id, nickname_length, nickname) do
    <<
      1 :: size(16),
      conn_id :: size(16),
      nickname_length :: size(8),
      nickname :: binary - size(nickname_length)
    >>
  end

  def player_left(conn_id) do
    <<
      2 :: size(16),
      conn_id :: size(16)
    >>
  end
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
end