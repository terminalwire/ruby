# frozen_string_literal: true

module Terminalwire::V2
  module Server
    # The server-role protocol state machine. Sans-IO: the application feeds it
    # incoming frames via #receive (getting back directives) and asks it to build
    # outgoing frames via the helper methods. No sockets, threads, or clock.
    #
    # A "directive" returned from #receive is one of:
    #   [:send, frame_hash]              — write this frame to the transport
    #   [:event, name_symbol, payload]   — a domain event for the application
    class Connection
      attr_reader :state, :protocol, :capabilities

      def initialize(server_min: Protocol::MIN_VERSION,
                     server_max: Protocol::MAX_VERSION,
                     server_capabilities: Protocol::CAPABILITIES,
                     mux: Mux.new)
        @server_min = server_min
        @server_max = server_max
        @server_capabilities = server_capabilities
        @mux = mux
        @state = :awaiting_hello
        @protocol = nil
        @capabilities = []
      end

      def ready?
        @state == :ready
      end

      # Feed one incoming frame. Returns an Array of directives (see class docs).
      def receive(frame)
        case @state
        when :awaiting_hello then on_hello(frame)
        when :ready          then on_ready(frame)
        else
          raise ProtocolError, "received #{frame["t"].inspect} while #{@state}"
        end
      end

      # --- application-driven outgoing helpers ---------------------------------

      # Open a stream (:stdout/:stderr output, or a stdin-raw input stream with a
      # line-discipline mode). Returns [sid, frame].
      def open_stream(stream, mode: nil)
        require_ready!
        sid = @mux.allocate
        [sid, Frames.open(sid: sid, stream: stream.to_s, mode: mode)]
      end

      # Build a data frame for an open output stream.
      def write(sid, bytes)
        require_ready!
        Frames.data(sid: sid, bytes: bytes)
      end

      def close_stream(sid)
        require_ready!
        Frames.close(sid: sid)
      end

      # Issue a resource request. Returns [sid, frame]; the response will arrive
      # later via #receive as [:event, :response, ...].
      def call(resource, method, params = {})
        require_ready!
        sid = @mux.allocate
        @mux.register(sid, { resource: resource, method: method })
        [sid, Frames.request(sid: sid, resource: resource.to_s, method: method.to_s, params: params)]
      end

      def exit(status = 0)
        @state = :closed
        Frames.exit(status: status)
      end

      private

      def on_hello(frame)
        unless frame["t"] == Protocol::Type::HELLO
          raise ProtocolError, "expected hello, got #{frame["t"].inspect}"
        end

        protocol = frame["protocol"]
        capabilities = frame["capabilities"]
        # Validate hello-specific fields up front so a malformed hello is a clean
        # ProtocolError rather than a NoMethodError deep in the negotiator.
        raise ProtocolError, "hello protocol must be an integer" unless protocol.is_a?(Integer)
        raise ProtocolError, "hello capabilities must be an array" unless capabilities.is_a?(Array)

        result = Negotiator.negotiate(
          client_protocol: protocol,
          client_capabilities: capabilities,
          server_min: @server_min,
          server_max: @server_max,
          server_capabilities: @server_capabilities
        )

        if result[:decision] == "welcome"
          @state = :ready
          @protocol = result[:protocol]
          @capabilities = result[:capabilities]
          [
            [:send, Frames.welcome(protocol: @protocol, capabilities: @capabilities)],
            [:event, :ready, { protocol: @protocol, capabilities: @capabilities,
                               program: frame["program"], entitlement: frame["entitlement"],
                               terminal: frame["terminal"], flow: frame["flow"] }]
          ]
        else
          @state = :closed
          message = "client speaks #{frame["protocol"]}; " \
                    "server supports #{@server_min}..#{@server_max}"
          [
            [:send, Frames.incompatible(supported: result[:supported], message: message)],
            [:event, :incompatible, { supported: result[:supported] }]
          ]
        end
      end

      # Single uniform dispatch over the inbound frame type (mirrors the Go
      # client's Process switch). Every client->server-while-ready frame is one
      # case here; an unrecognized type is a protocol violation.
      def on_ready(frame)
        case frame["t"]
        when Protocol::Type::SIGNAL      then on_signal(frame)
        when Protocol::Type::WINDOW_ADJUST
          [[:event, :window_adjust, { sid: frame["sid"], bytes: frame["bytes"] }]]
        when Protocol::Type::DATA        then on_input(frame)
        when Protocol::Type::RESPONSE    then on_response(frame)
        else
          raise ProtocolError, "unexpected #{frame["t"].inspect} while ready"
        end
      end

      # Unsolicited terminal signals (resize/interrupt). Unknown names are ignored
      # for forward compatibility — a newer client can send signals we don't know.
      def on_signal(frame)
        case frame["name"]
        when Protocol::Signal::RESIZE
          [[:event, :resize, { cols: frame["cols"], rows: frame["rows"] }]]
        when Protocol::Signal::INTERRUPT
          [[:event, :interrupt, {}]]
        else
          []
        end
      end

      # Client -> server data: keystrokes on a raw input stream the server opened.
      def on_input(frame)
        [[:event, :input, { sid: frame["sid"], bytes: frame["bytes"] }]]
      end

      def on_response(frame)
        # A response for an unknown/already-resolved stream (duplicate, late, or
        # hostile) is ignored rather than crashing the session.
        return [] unless @mux.pending?(frame["sid"])

        context = @mux.resolve(frame["sid"])
        [[:event, :response, {
          sid: frame["sid"], ok: frame["ok"], value: frame["value"],
          error: frame["error"], context: context
        }]]
      end

      def require_ready!
        raise ProtocolError, "connection not ready (state: #{@state})" unless ready?
      end
    end
  end
end
