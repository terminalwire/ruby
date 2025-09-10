module Terminalwire
  module Server
    class WebSocket
      include Logging

      def call(env)
        Async::WebSocket::Adapters::Rack.open(env, protocols: ['ws']) do |connection|
          handle(
            adapter: Adapter::Socket.new(Terminalwire::Transport::WebSocket.new(connection)),
            env:
          )
        end or [200, { "Content-Type" => "text/plain" }, ["Connect via WebSockets"]]
      end

      def handle(adapter:, env:)
        session = Terminalwire::Server::Session.new(adapter)
        context = nil

        while message = adapter.read
          next if session.ingest(message)

          case message
          in { event: "initialization", protocol:, program:, entitlement: }
            context ||= Terminalwire::Server::Context.new(adapter:, entitlement:)
          else
            logger.debug "Unhandled message: #{message.inspect}"
          end
        end
      ensure
        context&.close
      end
    end
  end
end
