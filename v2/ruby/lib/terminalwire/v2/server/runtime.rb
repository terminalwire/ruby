# frozen_string_literal: true

module Terminalwire::V2
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
        @raw_inputs = {}
        @lock = Mutex.new
        @ready = Queue.new
        @signaled = false
        @on_resize = nil
        @interrupted = false
      end

      # Register a callback fired (on the pump thread) whenever the client's
      # window resizes. The Terminal is already updated before it runs.
      def on_resize(&block)
        @on_resize = block
      end

      # Start the read pump and block until the handshake reaches ready (or fails).
      # The calling thread is the CLI thread; an interrupt signal is raised into it.
      def handshake
        @cli_thread = Thread.current
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

      # Open a raw input stream: the client puts its terminal in `mode` (raw or
      # cbreak) and streams keystrokes as data frames until we close it, restoring
      # the prior mode on close. Returns the stream id.
      def open_raw_input(mode: Protocol::Mode::RAW)
        sid, frame = @connection.open_stream(Protocol::Stream::STDIN_RAW, mode: mode)
        @lock.synchronize { @raw_inputs[sid] = Queue.new }
        emit(frame)
        sid
      end

      # Read the next keystroke chunk from a raw input stream; blocks until input
      # arrives, returns nil when the stream is closed or the connection dies.
      def read_raw(sid)
        queue = @lock.synchronize { @raw_inputs[sid] }
        return nil unless queue

        value = queue.pop
        # An interrupt and the connection's :closed both unblock this pop and can
        # race; the interrupt is the user's intent, so it wins (-> exit 130). This
        # makes the outcome deterministic regardless of which arrives first (the
        # async/Falcon bridge could let :closed land before Thread#raise lands).
        raise Interrupted if @interrupted

        value == :closed ? nil : value
      end

      def close_raw_input(sid)
        emit(@connection.close_stream(sid))
        queue = @lock.synchronize { @raw_inputs.delete(sid) }
        queue&.push(:closed) # unblock a pending read_raw
      end

      # Synchronous resource call: register a waiter, write the request, and block
      # until the pump delivers the correlated response (or the connection dies).
      def request(resource, method, params = {})
        sid, frame = @connection.call(resource, method, params)
        waiter = Queue.new
        @lock.synchronize { @waiters[sid] = waiter }
        emit(frame)

        answer = waiter.pop
        # Interrupt wins over a racing connection-closed failure (see read_raw).
        raise Interrupted if @interrupted
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
          frame =
            begin
              Codec.decode(bytes)
            rescue ProtocolError
              # A single malformed frame is dropped, not fatal — one bad frame must
              # not tear down the whole session (matches the Go client and the Elixir
              # server). The WebSocket transport delimits messages, so the next frame
              # is unaffected. State-machine violations from #receive stay fatal.
              next
            end
          route(@connection.receive(frame))
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
        # Unblock any read_raw waiting on a dead connection.
        @lock.synchronize { @raw_inputs.values }.each { |queue| queue.push(:closed) }
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
        when :interrupt
          # Deliver Ctrl-C into the CLI thread, like a local SIGINT — a blocked
          # request/read/sleep unwinds and the Handler turns it into exit 130.
          # Raise Interrupted, NOT Ruby's Interrupt: Interrupt is a SignalException,
          # and raising one into a thread inside a Falcon worker disturbs the async
          # reactor and kills the connection before the exit frame can flush (the
          # client then hangs). A plain Exception subclass interrupts the same
          # blocking calls without touching Falcon's signal machinery. Set the flag
          # BEFORE raising so a blocked read/request that unblocks via a racing
          # connection-close still sees the interrupt (see read_raw).
          @interrupted = true
          begin
            @cli_thread&.raise(Interrupted.new)
          rescue ThreadError
            nil
          end
        when :window_adjust
          @flow.grant(payload[:sid], payload[:bytes])
        when :input
          queue = @lock.synchronize { @raw_inputs[payload[:sid]] }
          queue&.push(payload[:bytes])
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
