# frozen_string_literal: true

module Terminalwire2
  module Server
    # Credit-based flow control for server -> client output streams (the SSH /
    # HTTP-2 window model). Each output stream has a window: the number of bytes
    # the client will accept before the server must wait. #consume is called on
    # the sending (CLI) thread before emitting a data frame and blocks when the
    # window is exhausted; #grant is called on the read-pump thread when a
    # window_adjust arrives and wakes the sender. This is what stops a fast server
    # from outrunning a slow client and ballooning the transport's buffers.
    #
    # The core invariant it enforces: at any instant, the bytes the server has
    # sent but not yet had credited never exceed the window the client granted.
    class FlowController
      def initialize
        @windows = {}
        @mutex = Mutex.new
        @cv = ConditionVariable.new
        @closed = false
        @error = nil
      end

      # Begin tracking a stream with an initial window (the client's offer).
      def open(sid, initial)
        @mutex.synchronize { @windows[sid] = initial }
      end

      # Reserve `bytes` of window for `sid`, blocking until enough credit exists.
      # Raises if the connection is shut down while waiting.
      def consume(sid, bytes)
        @mutex.synchronize do
          loop do
            raise(@error || ProtocolError.new("flow closed")) if @closed

            available = @windows[sid] || 0
            if available >= bytes
              @windows[sid] = available - bytes
              return
            end
            @cv.wait(@mutex)
          end
        end
      end

      # Reserve up to `max` bytes for `sid`, blocking only until at least one byte
      # of credit exists, then taking min(available, max). Returns the amount
      # taken. Sizing each frame to current credit means a single write larger
      # than the window never deadlocks. Raises if shut down while waiting.
      def reserve(sid, max)
        @mutex.synchronize do
          loop do
            raise(@error || ProtocolError.new("flow closed")) if @closed

            available = @windows[sid] || 0
            if available.positive?
              take = [available, max].min
              @windows[sid] = available - take
              return take
            end
            @cv.wait(@mutex)
          end
        end
      end

      # Return `bytes` of credit for `sid` (from a window_adjust) and wake senders.
      def grant(sid, bytes)
        @mutex.synchronize do
          # A grant for an unknown/closed stream is harmless and ignored.
          @windows[sid] = (@windows[sid] || 0) + bytes if @windows.key?(sid)
          @cv.broadcast
        end
      end

      def available(sid)
        @mutex.synchronize { @windows[sid] || 0 }
      end

      def close(sid)
        @mutex.synchronize { @windows.delete(sid) }
      end

      # Unblock every waiting sender with an error (connection died).
      def shutdown(error)
        @mutex.synchronize do
          @closed = true
          @error = error
          @cv.broadcast
        end
      end
    end
  end
end
