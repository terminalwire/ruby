# frozen_string_literal: true

module Terminalwire2
  module Server
    # Drives a Server::Connection over a transport. A background **read pump**
    # continuously drains incoming frames and routes them: responses go to the
    # caller blocked in #request, and unsolicited control frames (resize, and
    # later interrupt) update state / fire callbacks. This is what lets the
    # server always know the client's terminal size, not just while it happens to
    # be inside a request.
    #
    # Threading: the pump runs on its own thread; the CLI runs on the caller's
    # thread and blocks in #request on a per-stream queue the pump fulfills.
    class Runtime
      attr_reader :connection, :program, :entitlement, :terminal

      def initialize(transport:,
                     server_min: Protocol::MIN_VERSION,
                     server_max: Protocol::MAX_VERSION,
                     server_capabilities: Protocol::CAPABILITIES)
        @transport = transport
        @connection = Connection.new(
          server_min: server_min, server_max: server_max,
          server_capabilities: server_capabilities
        )
        @terminal = Terminal.new
        @waiters = {}
        @lock = Mutex.new
        @ready = Queue.new
        @signaled = false
        @on_resize = nil
      end

      # Register a callback fired (on the pump thread) whenever the client's
      # window resizes. The Terminal is already updated before it runs.
      def on_resize(&block)
        @on_resize = block
      end

      # Start the read pump and block until the handshake reaches ready (or fails).
      def handshake
        @pump = Thread.new { pump }
        result = @ready.pop
        raise result if result.is_a?(Exception)

        self
      end

      # Fire-and-forget: write a single frame (one-way output, exit).
      def emit(frame)
        @transport.write(Codec.encode(frame))
        nil
      end

      # Synchronous resource call: register a waiter, write the request, and block
      # until the pump delivers the correlated response (or the connection dies).
      def request(resource, method, params = {})
        sid, frame = @connection.call(resource, method, params)
        waiter = Queue.new
        @lock.synchronize { @waiters[sid] = waiter }
        emit(frame)

        answer = waiter.pop
        raise answer if answer.is_a?(Exception)

        unless answer[:ok]
          error = answer[:error] || {}
          raise ResponseError.new(error["code"] || "internal", error["message"] || "request failed")
        end
        answer[:value]
      end

      # Stop the pump and release the transport.
      def close
        @transport.close
        @pump&.join(2)
      end

      private

      def pump
        while (bytes = @transport.read)
          route(@connection.receive(Codec.decode(bytes)))
        end
        # transport closed
        signal_ready(ProtocolError.new("client closed before hello"))
        fail_waiters(ProtocolError.new("connection closed"))
      rescue StandardError => e
        signal_ready(e)
        fail_waiters(e)
      end

      def route(directives)
        directives.each do |kind, *rest|
          case kind
          when :send
            emit(rest[0])
          when :event
            handle_event(rest[0], rest[1])
          end
        end
      end

      def handle_event(name, payload)
        case name
        when :ready
          @program = payload[:program]
          @entitlement = payload[:entitlement]
          @terminal.apply(payload[:terminal])
          signal_ready(:ok)
        when :incompatible
          signal_ready(ProtocolError.new("incompatible client"))
        when :response
          waiter = @lock.synchronize { @waiters.delete(payload[:sid]) }
          waiter&.push(payload)
        when :resize
          @terminal.resize(cols: payload[:cols], rows: payload[:rows])
          @on_resize&.call(@terminal)
        end
      end

      # Signal the handshake exactly once.
      def signal_ready(value)
        @lock.synchronize do
          return if @signaled

          @signaled = true
        end
        @ready.push(value)
      end

      # Unblock every in-flight request so callers don't hang on a dead connection.
      def fail_waiters(error)
        @lock.synchronize do
          @waiters.each_value { |waiter| waiter.push(error) }
          @waiters.clear
        end
      end
    end
  end
end
