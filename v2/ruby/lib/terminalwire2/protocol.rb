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

    # Capabilities advertised by a fully-featured client/server.
    CAPABILITIES = %w[stdio file directory browser env].freeze

    # Frame types.
    module Type
      HELLO        = "hello"
      WELCOME      = "welcome"
      INCOMPATIBLE = "incompatible"
      EXIT         = "exit"
      OPEN         = "open"
      DATA         = "data"
      CLOSE        = "close"
      REQUEST      = "request"
      RESPONSE     = "response"
    end

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
