# frozen_string_literal: true

module Terminalwire::V2
  class Error < StandardError; end

  # Raised into the CLI thread to deliver a client Ctrl-C, like a local SIGINT —
  # but NOT a SignalException (Ruby's Interrupt). Raising the real Interrupt into a
  # thread inside a Falcon worker disturbs the async reactor and kills the
  # connection; a plain Exception subclass interrupts blocking calls without that.
  # Subclasses Exception (not StandardError) so user CLI code's `rescue
  # StandardError` can't swallow it — only the Handler catches it -> exit 130.
  class Interrupted < Exception; end

  # Raised when bytes off the wire are not a well-formed frame.
  class ProtocolError < Error; end

  # Raised on the server side when a `response` came back with ok: false.
  class ResponseError < Error
    attr_reader :code

    def initialize(code, message)
      @code = code
      super("#{code}: #{message}")
    end
  end
end
