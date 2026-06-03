# frozen_string_literal: true

module Terminalwire::V2
  # Allocates stream ids and correlates in-flight requests to their responses.
  # The starting id is injectable so recorded vectors replay deterministically.
  class Mux
    def initialize(start: 1)
      raise ArgumentError, "start must be >= 1 (0 is the control stream)" if start < 1

      @next = start
      @pending = {}
      # The runtime allocates/registers from the caller thread while the read
      # pump resolves from its own thread, so the registry is mutex-guarded.
      @mutex = Mutex.new
    end

    # Allocate a fresh stream id.
    def allocate
      @mutex.synchronize do
        sid = @next
        @next += 1
        sid
      end
    end

    # Mark a request stream as awaiting a response, stashing caller context.
    def register(sid, context = nil)
      @mutex.synchronize { @pending[sid] = context }
    end

    def pending?(sid)
      @mutex.synchronize { @pending.key?(sid) }
    end

    # Resolve a pending request, returning (and removing) its context.
    def resolve(sid)
      @mutex.synchronize do
        raise ProtocolError, "response for unknown stream #{sid}" unless @pending.key?(sid)

        @pending.delete(sid)
      end
    end

    def pending_count
      @mutex.synchronize { @pending.size }
    end
  end
end
