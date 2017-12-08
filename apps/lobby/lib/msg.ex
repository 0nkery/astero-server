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