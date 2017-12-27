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

defmodule Astero.Body do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    pos:  Astero.Coord.t,
    vel:  Astero.Coord.t,
    rot:  float,
    rvel: float,
    size: float
  }
  defstruct [:pos, :vel, :rot, :rvel, :size]

  field :pos, 1, required: true, type: Astero.Coord
  field :vel, 2, required: true, type: Astero.Coord
  field :rot, 3, optional: true, type: :float
  field :rvel, 4, optional: true, type: :float
  field :size, 5, optional: true, type: :float
end

defmodule Astero.Asteroid do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    body: Astero.Body.t,
    life: float
  }
  defstruct [:body, :life]

  field :body, 1, required: true, type: Astero.Body
  field :life, 2, required: true, type: :float
end

defmodule Astero.Asteroids do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entities: %{non_neg_integer => Astero.Asteroid.t}
  }
  defstruct [:entities]

  field :entities, 1, repeated: true, type: Astero.Asteroids.EntitiesEntry, map: true
end

defmodule Astero.Asteroids.EntitiesEntry do
  use Protobuf, map: true, syntax: :proto2

  @type t :: %__MODULE__{
    key:   non_neg_integer,
    value: Astero.Asteroid.t
  }
  defstruct [:key, :value]

  field :key, 1, optional: true, type: :uint32
  field :value, 2, optional: true, type: Astero.Asteroid
end

defmodule Astero.Shot do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    body: Astero.Body.t,
    ttl:  float
  }
  defstruct [:body, :ttl]

  field :body, 1, required: true, type: Astero.Body
  field :ttl, 2, required: true, type: :float
end

defmodule Astero.Shots do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entities: %{non_neg_integer => Astero.Shot.t}
  }
  defstruct [:entities]

  field :entities, 1, repeated: true, type: Astero.Shots.EntitiesEntry, map: true
end

defmodule Astero.Shots.EntitiesEntry do
  use Protobuf, map: true, syntax: :proto2

  @type t :: %__MODULE__{
    key:   non_neg_integer,
    value: Astero.Shot.t
  }
  defstruct [:key, :value]

  field :key, 1, optional: true, type: :uint32
  field :value, 2, optional: true, type: Astero.Shot
end

defmodule Astero.SimUpdate do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entity: integer,
    id:     non_neg_integer,
    body:   Astero.Body.t
  }
  defstruct [:entity, :id, :body]

  field :entity, 1, required: true, type: Astero.Entity, enum: true
  field :id, 2, required: true, type: :uint32
  field :body, 3, required: true, type: Astero.Body
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
    id:      non_neg_integer,
    body:    Astero.Body.t,
    latency: Astero.LatencyMeasure.t
  }
  defstruct [:id, :body, :latency]

  field :id, 1, required: true, type: :uint32
  field :body, 2, required: true, type: Astero.Body
  field :latency, 3, required: true, type: Astero.LatencyMeasure
end

defmodule Astero.OtherJoined do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id:       non_neg_integer,
    nickname: String.t,
    body:     Astero.Body.t
  }
  defstruct [:id, :nickname, :body]

  field :id, 1, required: true, type: :uint32
  field :nickname, 2, required: true, type: :string
  field :body, 3, required: true, type: Astero.Body
end

defmodule Astero.Leave do
  use Protobuf, syntax: :proto2

  defstruct []

end

defmodule Astero.OtherLeft do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id: non_neg_integer
  }
  defstruct [:id]

  field :id, 1, required: true, type: :uint32
end

defmodule Astero.Heartbeat do
  use Protobuf, syntax: :proto2

  defstruct []

end

defmodule Astero.LatencyMeasure do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    timestamp: non_neg_integer
  }
  defstruct [:timestamp]

  field :timestamp, 1, required: true, type: :uint64
end

defmodule Astero.Spawn do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entity:    {atom, any}
  }
  defstruct [:entity]

  oneof :entity, 0
  field :asteroids, 1, optional: true, type: Astero.Asteroids, oneof: 0
  field :shots, 2, optional: true, type: Astero.Shots, oneof: 0
end

defmodule Astero.SimUpdates do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    updates: [Astero.SimUpdate.t]
  }
  defstruct [:updates]

  field :updates, 1, repeated: true, type: Astero.SimUpdate
end

defmodule Astero.Input do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    turn:  integer,
    accel: integer,
    fire:  boolean
  }
  defstruct [:turn, :accel, :fire]

  field :turn, 1, optional: true, type: :sint32
  field :accel, 2, optional: true, type: :sint32
  field :fire, 3, optional: true, type: :bool
end

defmodule Astero.OtherInput do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id:    non_neg_integer,
    input: Astero.Input.t
  }
  defstruct [:id, :input]

  field :id, 1, required: true, type: :uint32
  field :input, 2, required: true, type: Astero.Input
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
  field :input, 4, optional: true, type: Astero.Input, oneof: 0
  field :latency, 5, optional: true, type: Astero.LatencyMeasure, oneof: 0
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
  field :heartbeat, 4, optional: true, type: Astero.Heartbeat, oneof: 0
  field :spawn, 5, optional: true, type: Astero.Spawn, oneof: 0
  field :sim_updates, 6, optional: true, type: Astero.SimUpdates, oneof: 0
  field :other_input, 7, optional: true, type: Astero.OtherInput, oneof: 0
  field :latency, 8, optional: true, type: Astero.LatencyMeasure, oneof: 0
end

defmodule Astero.Entity do
  use Protobuf, enum: true, syntax: :proto2

  field :UNKNOWN_ENTITY, 0
  field :ASTEROID, 1
  field :PLAYER, 2
end
