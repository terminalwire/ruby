require "thor"

module Terminalwire
  module Server
    class MyCLI < ::Thor
      include Terminalwire::Thor

      desc "greet NAME", "Greet a person"
      def greet(name)
        name = ask "What's your name?"
        say "Hello, #{name}!"
      end
    end

    class Socket
      include Logging

      def initialize(server_socket)
        @server_socket = server_socket
      end

      def listen
        logger.info "Socket: Listening..."
        loop do
          client_socket = @server_socket.accept
          logger.debug "Socket: Client #{client_socket.inspect} connected"
          handle_client(client_socket)
        end
      end

      private

      def handle_client(socket)
        transport = Transport::Socket.new(socket)
        adapter = Adapter.new(transport)

        Thread.new do
          handler = Handler.new(adapter)
          handler.run
        end
      end
    end

    class WebSocket
      include Logging

      def call(env)
        Async::WebSocket::Adapters::Rack.open(env, protocols: ['ws']) do |connection|
          run(Adapter.new(Terminalwire::Transport::WebSocket.new(connection)))
        end or [200, { "Content-Type" => "text/plain" }, ["Connect via WebSockets"]]
      end

      private

      def run(adapter)
        while message = adapter.recv
          puts message
        end
      end
    end

    class Thor < WebSocket
      include Logging

      def initialize(cli_class)
        @cli_class = cli_class

        unless @cli_class.included_modules.include?(Terminalwire::Thor)
          raise 'Add `include Terminalwire::Thor` to the #{@cli_class.inspect} class.'
        end
      end

      def run(adapter)
        logger.info "ThorServer: Running #{@cli_class.inspect}"
        while message = adapter.recv
          case message
          in { event: "initialization", protocol:, program: { arguments: }, entitlement: }
            Terminalwire::Server::Context.new(adapter:, entitlement:) do |context|
              @cli_class.start(arguments, context:)
            end
          end
        end
      end
    end

    class Handler
      include Logging

      def initialize(adapter)
        @adapter = adapter
      end

      def run
        logger.info "Server Handler: Running"
        loop do
          message = @adapter.recv
          case message
          in { event: "initialization", protocol:, program: { arguments: }, entitlement: }
            Context.new(adapter: @adapter) do |context|
              MyCLI.start(arguments, context:)
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET
        logger.info "Server Handler: Client disconnected"
      ensure
        @adapter.close
      end
    end

    def self.tcp(...)
      Server::Socket.new(TCPServer.new(...))
    end

    def self.socket(...)
      Server::Socket.new(UNIXServer.new(...))
    end
  end
end
