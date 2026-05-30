# frozen_string_literal: true

module Terminalwire2
  module Server
    # Drives a Server::Connection over a transport: performs the handshake, emits
    # one-way output frames, and runs synchronous resource requests. This is the
    # framework-agnostic seam — Rails/ActionCable, Rack, or a test harness all
    # supply a transport and let the Runtime do the protocol work.
    class Runtime
      attr_reader :connection, :program, :entitlement

      def initialize(transport:,
                     server_min: Protocol::MIN_VERSION,
                     server_max: Protocol::MAX_VERSION,
                     server_capabilities: Protocol::CAPABILITIES)
        @transport = transport
        @connection = Connection.new(
          server_min: server_min, server_max: server_max,
          server_capabilities: server_capabilities
        )
      end

      # Read the client's hello and reply. Returns self on success.
      def handshake
        frame = read_frame or raise ProtocolError, "client closed before hello"
        dispatch(@connection.receive(frame))
        raise ProtocolError, "handshake did not reach ready state" unless @connection.ready?

        self
      end

      # Fire-and-forget: write a single frame (used for one-way output and exit).
      def emit(frame)
        @transport.write(Codec.encode(frame))
        nil
      end

      # Synchronous resource call: write the request, pump frames until the
      # correlated response arrives. Raises ResponseError on a failed response.
      def request(resource, method, params = {})
        sid, frame = @connection.call(resource, method, params)
        emit(frame)

        loop do
          frame = read_frame or raise ProtocolError, "client closed during #{resource}.#{method}"
          answer = nil
          dispatch(@connection.receive(frame)) do |name, payload|
            answer = payload if name == :response && payload[:sid] == sid
          end
          next unless answer

          unless answer[:ok]
            error = answer[:error] || {}
            raise ResponseError.new(error["code"] || "internal", error["message"] || "request failed")
          end
          return answer[:value]
        end
      end

      private

      def read_frame
        bytes = @transport.read
        return nil if bytes.nil?

        Codec.decode(bytes)
      end

      # Apply directives from the connection: write :send frames, surface :event
      # to the optional block and capture handshake metadata.
      def dispatch(directives)
        directives.each do |directive|
          case directive[0]
          when :send
            emit(directive[1])
          when :event
            name, payload = directive[1], directive[2]
            if name == :ready
              @program = payload[:program]
              @entitlement = payload[:entitlement]
            end
            yield(name, payload) if block_given?
          end
        end
      end
    end
  end
end
