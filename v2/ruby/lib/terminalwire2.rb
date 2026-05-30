# frozen_string_literal: true

require_relative "terminalwire2/version"
require_relative "terminalwire2/errors"
require_relative "terminalwire2/protocol"
require_relative "terminalwire2/codec"
require_relative "terminalwire2/negotiator"
require_relative "terminalwire2/frames"
require_relative "terminalwire2/mux"
require_relative "terminalwire2/transport/memory"
require_relative "terminalwire2/server/connection"
require_relative "terminalwire2/server/runtime"
require_relative "terminalwire2/server/context"
require_relative "terminalwire2/server/handler"
require_relative "terminalwire2/conformance"

# Note: terminalwire2/server/thor is required on demand (it needs the thor gem),
# so the protocol core stays dependency-light.

# Terminalwire v2 — sans-IO protocol core and Ruby server runtime.
# See ../../PROTOCOL.md for the wire contract and ../../conformance for the
# language-neutral test corpus.
module Terminalwire2
end
