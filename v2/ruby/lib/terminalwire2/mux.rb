# frozen_string_literal: true

module Terminalwire2
  # Allocates stream ids and correlates in-flight requests to their responses.
  # The starting id is injectable so recorded vectors replay deterministically.
  class Mux
    def initialize(start: 1)
      raise ArgumentError, "start must be >= 1 (0 is the control stream)" if start < 1

      @next = start
      @pending = {}
    end

    # Allocate a fresh stream id.
    def allocate
      sid = @next
      @next += 1
      sid
    end

    # Mark a request stream as awaiting a response, stashing caller context.
    def register(sid, context = nil)
      @pending[sid] = context
    end

    def pending?(sid)
      @pending.key?(sid)
    end

    # Resolve a pending request, returning (and removing) its context.
    def resolve(sid)
      raise ProtocolError, "response for unknown stream #{sid}" unless @pending.key?(sid)

      @pending.delete(sid)
    end

    def pending_count
      @pending.size
    end
  end
end
