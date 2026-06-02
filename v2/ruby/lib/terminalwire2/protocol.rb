# frozen_string_literal: true

module Terminalwire2
  # Wire-level constants for the v2 protocol. See ../../PROTOCOL.md.
  module Protocol
    # Frame protocol version this implementation speaks.
    VERSION = 2

    # Range of protocol versions this implementation can negotiate.
    MIN_VERSION = 2
    MAX_VERSION = 2

    # The reserved control stream id.
    CONTROL_SID = 0

    # Capabilities advertised by a fully-featured client/server. Negotiation
    # intersects the two sides' sets, so a peer only uses a feature the other
    # advertises. ADD a capability here when you add an optional feature; that is
    # the additive-change path (old peers simply won't list it, and the feature
    # stays dormant for them). Resource capabilities gate request(); the others
    # gate optional protocol features.
    CAPABILITIES = %w[
      stdio file directory browser env
      signal flow raw-input
    ].freeze

    # Output stream names (open.stream).
    module Stream
      STDOUT    = "stdout"
      STDERR    = "stderr"
      STDIN_RAW = "stdin-raw"
    end

    # Frame types.
    module Type
      HELLO        = "hello"
      WELCOME      = "welcome"
      INCOMPATIBLE = "incompatible"
      EXIT         = "exit"
      OPEN         = "open"
      DATA         = "data"
      CLOSE        = "close"
      REQUEST       = "request"
      RESPONSE      = "response"
      SIGNAL        = "signal"
      WINDOW_ADJUST = "window_adjust"
    end

    # Names carried by a `signal` frame (client -> server, async terminal events).
    module Signal
      RESIZE    = "resize"
      INTERRUPT = "interrupt"
    end

    # Default initial per-output-stream flow-control window (bytes) the client
    # grants the server. Must be >= the server's output chunk size so a single
    # chunk can never exceed an empty window and deadlock.
    DEFAULT_WINDOW = 256 * 1024

    # Error codes carried on a `response` with ok: false.
    module ErrorCode
      DENIED    = "denied"
      NOT_FOUND = "not_found"
      IO        = "io"
      PROTOCOL  = "protocol"
      INTERNAL  = "internal"
    end
  end
end
