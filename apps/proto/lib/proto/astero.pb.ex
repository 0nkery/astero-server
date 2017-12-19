defmodule Astero.Coord do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    x: float,
    y: float
  }
  defstruct [:x, :y]

  field :x, 1, required: true, type: :float
  field :y, 2, required: true, type: :float
end

defmodule Astero.Asteroid do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    pos:      Astero.Coord.t,
    velocity: Astero.Coord.t,
    facing:   float,
    rvel:     float,
    life:     float
  }
  defstruct [:pos, :velocity, :facing, :rvel, :life]

  field :pos, 1, required: true, type: Astero.Coord
  field :velocity, 2, required: true, type: Astero.Coord
  field :facing, 3, required: true, type: :float
  field :rvel, 4, required: true, type: :float
  field :life, 5, required: true, type: :float
end

defmodule Astero.Asteroids do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entities: %{integer => Astero.Asteroid.t}
  }
  defstruct [:entities]

  field :entities, 1, repeated: true, type: Astero.Asteroids.EntitiesEntry, map: true
end

defmodule Astero.Asteroids.EntitiesEntry do
  use Protobuf, map: true, syntax: :proto2

  @type t :: %__MODULE__{
    key:   integer,
    value: Astero.Asteroid.t
  }
  defstruct [:key, :value]

  field :key, 1, optional: true, type: :int32
  field :value, 2, optional: true, type: Astero.Asteroid
end

defmodule Astero.Join do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    nickname: String.t
  }
  defstruct [:nickname]

  field :nickname, 1, required: true, type: :string
end

defmodule Astero.JoinAck do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id:  integer,
    pos: Astero.Coord.t
  }
  defstruct [:id, :pos]

  field :id, 1, required: true, type: :int32
  field :pos, 2, required: true, type: Astero.Coord
end

defmodule Astero.OtherJoined do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id:       integer,
    nickname: String.t,
    pos:      Astero.Coord.t
  }
  defstruct [:id, :nickname, :pos]

  field :id, 1, required: true, type: :int32
  field :nickname, 2, required: true, type: :string
  field :pos, 3, required: true, type: Astero.Coord
end

defmodule Astero.Leave do
  use Protobuf, syntax: :proto2

  defstruct []

end

defmodule Astero.OtherLeft do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id: integer
  }
  defstruct [:id]

  field :id, 1, required: true, type: :int32
end

defmodule Astero.Spawn do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entity:    {atom, any}
  }
  defstruct [:entity]

  oneof :entity, 0
  field :asteroids, 1, optional: true, type: Astero.Asteroids, oneof: 0
end

defmodule Astero.Heartbeat do
  use Protobuf, syntax: :proto2

  defstruct []

end

defmodule Astero.Client do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    msg:       {atom, any}
  }
  defstruct [:msg]

  oneof :msg, 0
  field :join, 1, optional: true, type: Astero.Join, oneof: 0
  field :leave, 2, optional: true, type: Astero.Leave, oneof: 0
  field :heartbeat, 3, optional: true, type: Astero.Heartbeat, oneof: 0
end

defmodule Astero.Server do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    msg:          {atom, any}
  }
  defstruct [:msg]

  oneof :msg, 0
  field :join_ack, 1, optional: true, type: Astero.JoinAck, oneof: 0
  field :other_joined, 2, optional: true, type: Astero.OtherJoined, oneof: 0
  field :other_left, 3, optional: true, type: Astero.OtherLeft, oneof: 0
  field :spawn, 4, optional: true, type: Astero.Spawn, oneof: 0
  field :heartbeat, 5, optional: true, type: Astero.Heartbeat, oneof: 0
end
