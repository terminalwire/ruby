# frozen_string_literal: true

module Terminalwire::V2
  class Error < StandardError; end

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
