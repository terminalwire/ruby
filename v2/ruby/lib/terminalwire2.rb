# frozen_string_literal: true

require_relative "terminalwire2/version"
require_relative "terminalwire2/errors"
require_relative "terminalwire2/protocol"
require_relative "terminalwire2/codec"
require_relative "terminalwire2/negotiator"
require_relative "terminalwire2/frames"
require_relative "terminalwire2/mux"
require_relative "terminalwire2/server/connection"
require_relative "terminalwire2/conformance"

# Terminalwire v2 — sans-IO protocol core and Ruby server runtime.
# See ../../PROTOCOL.md for the wire contract and ../../conformance for the
# language-neutral test corpus.
module Terminalwire2
end
