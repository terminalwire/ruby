# frozen_string_literal: true

require "thread"

module Terminalwire::V2
  module Transport
    # A blocking in-memory duplex transport. Two ends share a pair of queues, so
    # one end's #write is the other end's #read. Used for tests and in-process
    # wiring; production uses a WebSocket-backed transport with the same interface
    # (#read -> bytes/nil, #write(bytes), #close).
    class Memory
      EOF = :__eof__

      def self.pair
        a = ::Queue.new
        b = ::Queue.new
        [new(read_queue: a, write_queue: b), new(read_queue: b, write_queue: a)]
      end

      def initialize(read_queue:, write_queue:)
        @read_queue = read_queue
        @write_queue = write_queue
      end

      # @return [String, nil] the next frame's bytes, or nil once closed.
      def read
        value = @read_queue.pop
        value == EOF ? nil : value
      end

      def write(bytes)
        @write_queue.push(bytes)
      end

      def close
        @write_queue.push(EOF)
      end
    end
  end
end
