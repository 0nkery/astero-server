defmodule Mmob.JoinGame do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    payload: String.t
  }
  defstruct [:payload]

  field :payload, 1, optional: true, type: :bytes
end

defmodule Mmob.JoinAck do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    payload: String.t
  }
  defstruct [:payload]

  field :payload, 1, optional: true, type: :bytes
end

defmodule Mmob.LeaveGame do
  use Protobuf, syntax: :proto2

  defstruct []

end

defmodule Mmob.Heartbeat do
  use Protobuf, syntax: :proto2

  defstruct []

end

defmodule Mmob.LatencyMeasure do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    timestamp: non_neg_integer
  }
  defstruct [:timestamp]

  field :timestamp, 1, required: true, type: :uint64
end

defmodule Mmob.Proxied do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    msg: String.t
  }
  defstruct [:msg]

  field :msg, 1, required: true, type: :bytes
end

defmodule Mmob.Client do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    Msg:             {atom, any}
  }
  defstruct [:Msg]

  oneof :Msg, 0
  field :join, 1, optional: true, type: Mmob.JoinGame, oneof: 0
  field :leave, 2, optional: true, type: Mmob.LeaveGame, oneof: 0
  field :heartbeat, 3, optional: true, type: Mmob.Heartbeat, oneof: 0
  field :latency_measure, 4, optional: true, type: Mmob.LatencyMeasure, oneof: 0
  field :proxied, 5, optional: true, type: Mmob.Proxied, oneof: 0
end

defmodule Mmob.Server do
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
    Msg:             {atom, any}
  }
  defstruct [:Msg]

  oneof :Msg, 0
  field :join_ack, 1, optional: true, type: Mmob.JoinAck, oneof: 0
  field :heartbeat, 2, optional: true, type: Mmob.Heartbeat, oneof: 0
  field :latency_measure, 3, optional: true, type: Mmob.LatencyMeasure, oneof: 0
  field :proxied, 4, optional: true, type: Mmob.Proxied, oneof: 0
end
