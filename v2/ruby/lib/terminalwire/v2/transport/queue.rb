# frozen_string_literal: true

require "thread"

module Terminalwire::V2
  module Transport
    # A queue-backed transport for callback-driven servers (ActionCable, async
    # websocket Rack endpoints, etc.). The endpoint pushes each received frame
    # with #deliver; the blocking Runtime consumes them via #read. Outgoing frames
    # are handed to the sink callable. This bridges an event-loop/callback world to
    # the synchronous server runtime.
    class Queue
      CLOSED = Object.new

      def initialize(sink:)
        @sink = sink
        @inbox = ::Queue.new
        @mutex = Mutex.new
        @closed = false
      end

      # Called by the websocket endpoint when a frame arrives from the client.
      def deliver(bytes)
        @mutex.synchronize { @inbox << bytes unless @closed }
      end

      def read
        value = @inbox.pop
        value.equal?(CLOSED) ? nil : value
      end

      def write(bytes)
        @sink.call(bytes)
      end

      def close
        @mutex.synchronize do
          next if @closed

          @closed = true
          @inbox << CLOSED
        end
      end
    end
  end
end
