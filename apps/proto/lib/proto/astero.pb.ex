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
    id:   non_neg_integer,
    body: Astero.Body.t,
    life: float
  }
  defstruct [:id, :body, :life]

  field :id, 1, required: true, type: :uint32
  field :body, 2, required: true, type: Astero.Body
  field :life, 3, optional: true, type: :float
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

defmodule Astero.Player do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id:       non_neg_integer,
    body:     Astero.Body.t,
    nickname: String.t,
    life:     float
  }
  defstruct [:id, :body, :nickname, :life]

  field :id, 1, required: true, type: :uint32
  field :body, 2, required: true, type: Astero.Body
  field :nickname, 3, optional: true, type: :string
  field :life, 4, optional: true, type: :float
end

defmodule Astero.Create do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entity:   {atom, any}
  }
  defstruct [:entity]

  oneof :entity, 0
  field :player, 1, optional: true, type: Astero.Player, oneof: 0
  field :asteroid, 2, optional: true, type: Astero.Asteroid, oneof: 0
  field :shot, 3, optional: true, type: Astero.Shot, oneof: 0
end

defmodule Astero.Destroy do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    id:     non_neg_integer,
    entity: integer
  }
  defstruct [:id, :entity]

  field :id, 1, required: true, type: :uint32
  field :entity, 2, required: true, type: Astero.Entity, enum: true
end

defmodule Astero.Update do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    entity:   {atom, any}
  }
  defstruct [:entity]

  oneof :entity, 0
  field :player, 1, optional: true, type: Astero.Player, oneof: 0
  field :asteroid, 2, optional: true, type: Astero.Asteroid, oneof: 0
end

defmodule Astero.ManyUpdates do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    updates: [Astero.Update.t]
  }
  defstruct [:updates]

  field :updates, 1, repeated: true, type: Astero.Update
end

defmodule Astero.JoinPayload do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    nickname: String.t
  }
  defstruct [:nickname]

  field :nickname, 1, required: true, type: :string
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

defmodule Astero.Client do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    msg:   {atom, any}
  }
  defstruct [:msg]

  oneof :msg, 0
  field :input, 1, optional: true, type: Astero.Input, oneof: 0
end

defmodule Astero.Server do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    msg:     {atom, any}
  }
  defstruct [:msg]

  oneof :msg, 0
  field :create, 1, optional: true, type: Astero.Create, oneof: 0
  field :destroy, 2, optional: true, type: Astero.Destroy, oneof: 0
  field :updates, 3, optional: true, type: Astero.ManyUpdates, oneof: 0
end

defmodule Astero.Entity do
  use Protobuf, enum: true, syntax: :proto2

  field :UNKNOWN, 0
  field :ASTEROID, 1
  field :PLAYER, 2
end
