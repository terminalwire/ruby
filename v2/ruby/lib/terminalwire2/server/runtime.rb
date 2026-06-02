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
      # Largest payload in a single output data frame; actual frame size is
      # min(this, available flow credit).
      MAX_FRAME = 32 * 1024

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
        @flow = FlowController.new
        @client_window = Protocol::DEFAULT_WINDOW
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

      # Fire-and-forget: write a single control frame (welcome, exit, request,
      # open/close). NOT flow-controlled — these are small control-plane frames.
      def emit(frame)
        @transport.write(Codec.encode(frame))
        nil
      end

      # Open an output stream (:stdout/:stderr) and start its flow window at the
      # client's advertised offer. Returns the stream id.
      def open_output(stream)
        sid, frame = @connection.open_stream(stream)
        @flow.open(sid, @client_window)
        emit(frame)
        sid
      end

      # Write output to a stream, flow-controlled: each frame is sized to the
      # currently available credit (blocking when the window is empty), so the
      # server can never outrun the client. Raises if the connection dies.
      def write_data(sid, bytes)
        bytes = bytes.b
        total = bytes.bytesize
        if total.zero?
          emit(Frames.data(sid: sid, bytes: "".b))
          return
        end

        offset = 0
        while offset < total
          take = @flow.reserve(sid, [total - offset, MAX_FRAME].min)
          emit(Frames.data(sid: sid, bytes: bytes.byteslice(offset, take)))
          offset += take
        end
      end

      def close_output(sid)
        emit(@connection.close_stream(sid))
        @flow.close(sid)
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
        shutdown(ProtocolError.new("client closed before hello"),
                 ProtocolError.new("connection closed"))
      rescue StandardError => e
        shutdown(e, e)
      end

      # Release everyone blocked on the connection: handshake waiter, in-flight
      # requests, and senders blocked on flow credit.
      def shutdown(ready_error, waiter_error)
        signal_ready(ready_error)
        fail_waiters(waiter_error)
        @flow.shutdown(waiter_error)
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
          @client_window = payload.dig(:flow, "window") || Protocol::DEFAULT_WINDOW
          signal_ready(:ok)
        when :incompatible
          signal_ready(ProtocolError.new("incompatible client"))
        when :response
          waiter = @lock.synchronize { @waiters.delete(payload[:sid]) }
          waiter&.push(payload)
        when :resize
          @terminal.resize(cols: payload[:cols], rows: payload[:rows])
          @on_resize&.call(@terminal)
        when :window_adjust
          @flow.grant(payload[:sid], payload[:bytes])
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
