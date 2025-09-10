# frozen_string_literal: true

require "securerandom"
require "async"
require "terminalwire"

module Terminalwire
  module Server
    # Session multiplexes requests over a single adapter using request IDs.
    # - It assigns an ID to each outbound request.
    # - It runs a reader task that routes incoming responses to the correct waiter by ID.
    # - It returns a waiter you can `.wait` on (fiber-friendly) or you can collect and wait later to pipeline.
    #
    # Usage:
    #   session = Terminalwire::Server::Session.new(adapter)
    #   waiter = session.request(event: "resource", action: "command", name: "file", command: "read", parameters: {path: "/etc/hosts"})
    #   data = waiter.wait # suspends the current fiber until response arrives
    class Session
      def initialize(adapter)
        @adapter = adapter
        @write_lock = Async::Semaphore.new(1)
        @pending = {}
      end

      # Send a request to the client. Returns a waiter you can `.wait` on.
      # The message will be merged with a unique :id and written atomically.
      #
      # Example:
      #   waiter = session.request(event: "resource", action: "command", name: "stdout", command: "print_line", parameters: {data: "hello"})
      #   waiter.wait
      def request(message)
        id = (message[:id] || SecureRandom.uuid).to_s

        waiter = Waiter.new
        @pending[id] = waiter

        # Serialize writes so the underlying transport doesn't interleave frames.
        @write_lock.acquire do
          @adapter.write(message.merge(id:))
        end

        waiter
      rescue => e
        # Ensure we don't leave a dangling pending entry on immediate failure.
        @pending.delete(id)
        raise
      end

      # Convenience wrapper to send a request and wait for the response.
      # Optional timeout in seconds.
      def request!(message, timeout: nil)
        waiter = request(message)
        waiter.wait(timeout: timeout)
      end

      # Shut down the session reader and reject all pending waiters.
      def close
        error = Terminalwire::Error.new("Session closed")
        pendings = @pending
        @pending = {}
        pendings.each_value { |w| w.reject(error) }
      end

      private

      public

      # Ingest a single message read by an external loop and route it to the appropriate waiter.
      # Returns true if the message was handled, false otherwise.
      def ingest(msg)
        case msg[:event]
        when "resource"
          id = msg[:id]&.to_s
          if id && (waiter = @pending.delete(id))
            case msg[:status]
            when "success"
              waiter.fulfill(msg[:response])
            when "failure"
              details = msg[:error] || msg
              waiter.reject(Terminalwire::Error.new(details.inspect))
            else
              waiter.reject(Terminalwire::Error.new("Unknown response: #{msg.inspect}"))
            end
            true
          else
            false
          end
        when "exit"
          error = Terminalwire::Error.new("Remote requested exit")
          pendings = @pending
          @pending = {}
          pendings.each_value { |w| w.reject(error) }
          false
        else
          false
        end
      end

      # Minimal fiber-friendly waiter implemented with Async::Condition.
      class Waiter
        def initialize
          @condition = Async::Condition.new
          @result = nil
          @error = nil
          @completed = false
        end

        def fulfill(value)
          return if @completed
          @completed = true
          @result = value
          @condition.signal
        end

        def reject(error)
          return if @completed
          @completed = true
          @error = error
          @condition.signal
        end

        # Wait for the result. Optional timeout in seconds.
        def wait(timeout: nil)
          if !@completed
            if timeout
              Async::Clock.timeout(timeout) { @condition.wait }
            else
              @condition.wait
            end
          end

          raise @error if @error
          @result
        end
      end
    end
  end
end