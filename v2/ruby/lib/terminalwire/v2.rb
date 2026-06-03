# frozen_string_literal: true

# Define the parent namespace before any nested file reopens Terminalwire::V2,
# so `module Terminalwire::V2` never hits an undefined constant.
module Terminalwire
  module V2
  end
end

require_relative "v2/version"
require_relative "v2/errors"
require_relative "v2/protocol"
require_relative "v2/codec"
require_relative "v2/negotiator"
require_relative "v2/frames"
require_relative "v2/mux"
require_relative "v2/window"
require_relative "v2/transport/memory"
require_relative "v2/transport/queue"
require_relative "v2/server/terminal"
require_relative "v2/server/flow"
require_relative "v2/server/connection"
require_relative "v2/server/runtime"
require_relative "v2/server/context"
require_relative "v2/server/io"
require_relative "v2/server/stream_router"
require_relative "v2/server/redirect"
require_relative "v2/server/handler"
require_relative "v2/server/session"
require_relative "v2/conformance"

# Note: terminalwire/v2/server/thor is required on demand (it needs the thor gem),
# so the protocol core stays dependency-light.

# Terminalwire v2 — sans-IO protocol core and Ruby server runtime.
# See ../../PROTOCOL.md for the wire contract and ../../conformance for the
# language-neutral test corpus.
module Terminalwire::V2
end
