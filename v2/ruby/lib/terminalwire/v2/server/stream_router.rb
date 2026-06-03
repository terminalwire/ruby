# frozen_string_literal: true

module Terminalwire::V2
  module Server
    # A stand-in for a global IO stream ($stdout/$stderr/$stdin) that dispatches
    # every call to a **fiber-local** target, falling back to the real stream when
    # no command is currently redirecting on this fiber.
    #
    # This is what makes redirection concurrency-safe: instead of mutating the
    # process-global $stdout per command (which interleaves when two run at once),
    # we install ONE router as $stdout for the whole process and let each fiber
    # point its own target at its own client. `Thread.current[]` is fiber-local in
    # Ruby, so this isolates both threaded servers (Puma) and fiber-per-request
    # servers (Falcon).
    class StreamRouter
      # @param key [Symbol] fiber-local key, e.g. :terminalwire_stdout
      # @param fallback [IO] the real stream to use when no redirect is active
      def initialize(key, fallback)
        @key = key
        @fallback = fallback
      end

      # The stream this fiber's calls should go to right now.
      def __target__ = Thread.current[@key] || @fallback

      # Set/clear the fiber-local target. Returns the previous value so callers
      # can restore exactly (supporting nesting).
      def __bind__(target)
        previous = Thread.current[@key]
        Thread.current[@key] = target
        previous
      end

      def __restore__(previous) = Thread.current[@key] = previous

      # Delegate everything to the current target. We forward the common methods
      # explicitly (fast path + clear intent) and method_missing the long tail so
      # the router is a faithful IO stand-in for whatever a CLI library calls.
      %i[print puts write << printf p flush sync sync= gets getpass read
         each_line each tty? isatty winsize fileno print_line].each do |m|
        define_method(m) do |*args, &block|
          __target__.public_send(m, *args, &block)
        end
      end

      def respond_to_missing?(name, include_private = false)
        __target__.respond_to?(name, include_private) || super
      end

      def method_missing(name, *args, &block)
        target = __target__
        if target.respond_to?(name)
          target.public_send(name, *args, &block)
        else
          super
        end
      end
    end
  end
end
