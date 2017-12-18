defmodule Astero.Coord do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    x: float,
    y: float
  }
  defstruct [:x, :y]

  field :x, 1, type: :float
  field :y, 2, type: :float
end

defmodule Astero.Asteroid do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    id:       integer,
    pos:      Astero.Coord.t,
    velocity: Astero.Coord.t,
    facing:   float,
    rvel:     float,
    life:     float
  }
  defstruct [:id, :pos, :velocity, :facing, :rvel, :life]

  field :id, 1, type: :int32
  field :pos, 2, type: Astero.Coord
  field :velocity, 3, type: Astero.Coord
  field :facing, 4, type: :float
  field :rvel, 5, type: :float
  field :life, 6, type: :float
end

defmodule Astero.Asteroids do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    asteroids: [Astero.Asteroid.t]
  }
  defstruct [:asteroids]

  field :asteroids, 1, repeated: true, type: Astero.Asteroid
end

defmodule Astero.Join do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    nickname: String.t
  }
  defstruct [:nickname]

  field :nickname, 1, type: :string
end

defmodule Astero.JoinAck do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    id:  integer,
    pos: Astero.Coord.t
  }
  defstruct [:id, :pos]

  field :id, 1, type: :int32
  field :pos, 2, type: Astero.Coord
end

defmodule Astero.OtherJoined do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    id:       integer,
    nickname: String.t,
    pos:      Astero.Coord.t
  }
  defstruct [:id, :nickname, :pos]

  field :id, 1, type: :int32
  field :nickname, 2, type: :string
  field :pos, 3, type: Astero.Coord
end

defmodule Astero.Leave do
  use Protobuf, syntax: :proto3

  defstruct []

end

defmodule Astero.OtherLeft do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    id: integer
  }
  defstruct [:id]

  field :id, 1, type: :int32
end

defmodule Astero.Spawn do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    entity:    {atom, any}
  }
  defstruct [:entity]

  oneof :entity, 0
  field :asteroids, 1, type: Astero.Asteroids, oneof: 0
end

defmodule Astero.Heartbeat do
  use Protobuf, syntax: :proto3

  defstruct []

end

defmodule Astero.Client do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    msg:   {atom, any}
  }
  defstruct [:msg]

  oneof :msg, 0
  field :join, 1, type: Astero.Join, oneof: 0
  field :leave, 2, type: Astero.Leave, oneof: 0
end

defmodule Astero.Server do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    msg:          {atom, any}
  }
  defstruct [:msg]

  oneof :msg, 0
  field :join_ack, 1, type: Astero.JoinAck, oneof: 0
  field :other_joined, 2, type: Astero.OtherJoined, oneof: 0
  field :other_left, 3, type: Astero.OtherLeft, oneof: 0
  field :spawn, 4, type: Astero.Spawn, oneof: 0
end