# frozen_string_literal: true

require "msgpack"

module Terminalwire2
  # Pure bytes <-> frame conversion. A frame is a Hash with string keys (the wire
  # shape). No I/O, no transport — this is the sans-IO seam the conformance corpus
  # exercises directly.
  module Codec
    module_function

    # @param frame [Hash] a frame with string keys
    # @return [String] MessagePack bytes (binary encoding)
    def encode(frame)
      raise ProtocolError, "frame must be a Hash, got #{frame.class}" unless frame.is_a?(Hash)

      MessagePack.pack(frame)
    end

    # @param bytes [String] MessagePack bytes for exactly one frame
    # @return [Hash] the decoded frame with string keys
    # @raise [ProtocolError] if the bytes are not a well-formed frame
    def decode(bytes)
      obj =
        begin
          MessagePack.unpack(bytes)
        rescue StandardError => e
          raise ProtocolError, "malformed msgpack: #{e.message}"
        end

      raise ProtocolError, "frame must be a map" unless obj.is_a?(Hash)
      raise ProtocolError, "frame missing string 't'" unless obj["t"].is_a?(String)
      raise ProtocolError, "frame missing integer 'sid'" unless obj["sid"].is_a?(Integer)

      obj
    end
  end
end
