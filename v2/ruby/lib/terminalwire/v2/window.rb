# frozen_string_literal: true

module Terminalwire::V2
  # The flow-control credit rule, as a pure ledger — no threads, no I/O. This is
  # the *protocol* part of flow control: how much output may be in flight, and how
  # window_adjust extends it. The blocking behaviour when credit runs out is an
  # implementation concern layered on top (see Server::FlowController); the rule
  # itself is deterministic and identical across implementations, so it is
  # exercised by the language-neutral flow corpus in ../../conformance.
  class Window
    attr_reader :available

    def initialize(size)
      @available = size > Protocol::MAX_WINDOW ? Protocol::MAX_WINDOW : size
    end

    # The number of bytes that may be sent right now toward a request for `want`:
    # min(want, available). Decrements the window by that amount and returns it.
    def take(want)
      amount = want < @available ? want : @available
      amount = 0 if amount.negative?
      @available -= amount
      amount
    end

    # Extend the window (a window_adjust arrived), clamped to the protocol ceiling
    # (Protocol::MAX_WINDOW) so a peer can't grow the window without bound.
    def grant(bytes)
      @available += bytes
      @available = Protocol::MAX_WINDOW if @available > Protocol::MAX_WINDOW
    end
  end
end
