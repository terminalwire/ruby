# frozen_string_literal: true

require "msgpack"

module Terminalwire::V2
  # Pure bytes <-> frame conversion. A frame is a Hash with string keys (the wire
  # shape). No I/O, no transport — this is the sans-IO seam the conformance corpus
  # exercises directly.
  module Codec
    # Largest valid stream id: a signed 64-bit max. Go decodes sids into int64, so
    # anything above this would wrap to a negative (colliding) sid there; bounding
    # it here keeps all three impls' sid validity identical.
    MAX_SID = (1 << 63) - 1

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
      # 't' must be a NON-EMPTY type string. Go and Elixir reject "" at the codec;
      # Ruby used to let it through to the state machine. An empty type is not a
      # valid frame — reject it here so all three behave identically.
      raise ProtocolError, "frame missing string 't'" unless obj["t"].is_a?(String) && !obj["t"].empty?
      # 'sid' must be a non-negative integer that fits in a signed 64-bit int (see
      # MAX_SID): real sids are small and server-allocated, and the range bound keeps
      # the three impls aligned (Go would otherwise wrap a uint64 sid to a negative).
      sid = obj["sid"]
      unless sid.is_a?(Integer) && sid >= 0 && sid <= MAX_SID
        raise ProtocolError, "frame missing integer 'sid'"
      end

      obj
    end
  end
end
