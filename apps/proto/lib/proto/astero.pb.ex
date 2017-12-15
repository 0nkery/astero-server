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
    pos:      Astero.Coord.t,
    velocity: Astero.Coord.t,
    facing:   float,
    rvel:     float,
    life:     float
  }
  defstruct [:pos, :velocity, :facing, :rvel, :life]

  field :pos, 1, type: Astero.Coord
  field :velocity, 2, type: Astero.Coord
  field :facing, 3, type: :float
  field :rvel, 4, type: :float
  field :life, 5, type: :float
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

defmodule Astero.SpawnAsteroid do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    asteroids: [Astero.Asteroid.t]
  }
  defstruct [:asteroids]

  field :asteroids, 1, repeated: true, type: Astero.Asteroid
end

defmodule Astero.Heartbeat do
  use Protobuf, syntax: :proto3

  defstruct []

end
