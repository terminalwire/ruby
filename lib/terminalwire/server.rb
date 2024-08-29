module Terminalwire
  module Server
    module Resource
      class IO < Terminalwire::Resource::Base
        def puts(data)
          command("puts", data: data)
        end

        def print(data)
          command("print", data: data)
        end

        def gets
          command("gets")
        end

        def flush
          # @connection.flush
        end

        private

        def command(command, data: nil)
          @connection.write(event: "device", id: @id, action: "command", command: command, data: data)
          @connection.recv&.fetch(:response)
        end
      end

      class STDOUT < IO
      end

      class STDIN < IO
        def getpass
          command("getpass")
        end
      end

      class STDERR < IO
      end

      class File < Terminalwire::Resource::Base
        def read(path)
          command("read", path.to_s)
        end

        def write(path, content)
          command("write", { 'path' => path.to_s, 'content' => content })
        end

        def append(path, content)
          command("append", { 'path' => path.to_s, 'content' => content })
        end

        def mkdir(path)
          command("mkdir", { 'path' => path.to_s })
        end

        def exist?(path)
          command("exist", { 'path' => path.to_s })
        end

        private

        def command(action, data)
          @connection.write(event: "device", id: @id, action: "command", command: action, data: data)
          response = @connection.recv
          response.fetch(:response)
        end
      end

      class Browser < Terminalwire::Resource::Base
        def launch(url)
          command("launch", data: url)
        end

        private

        def command(command, data: nil)
          @connection.write(event: "device", id: @id, action: "command", command: command, data: data)
          @connection.recv.fetch(:response)
        end
      end
    end

    class ResourceMapper
      include Logging

      def initialize(connection, resources = self.class.resources)
        @id = -1
        @resources = resources
        @devices = Hash.new { |h,k| h[Integer(k)] }
        @connection = connection
      end

      def connect_device(type)
        id = next_id
        logger.debug "Server: Requesting client to connect device #{type} with ID #{id}"
        @connection.write(event: "device", action: "connect", id: id, type: type)
        response = @connection.recv
        case response
        in { status: "success" }
          logger.debug "Server: Resource #{type} connected with ID #{id}."
          @devices[id] = @resources.find(type).new(id, @connection)
        else
          logger.debug "Server: Failed to connect device #{type} with ID #{id}."
        end
      end

      private

      def next_id
        @id += 1
      end

      def self.resources
        ResourceRegistry.new.tap do |resources|
          resources << Server::Resource::STDOUT
          resources << Server::Resource::STDIN
          resources << Server::Resource::STDERR
          resources << Server::Resource::Browser
          resources << Server::Resource::File
        end
      end
    end

    class Session
      extend Forwardable

      attr_reader :stdout, :stdin, :stderr, :browser, :file

      def_delegators :@stdout, :puts, :print
      def_delegators :@stdin, :gets, :getpass

      def initialize(connection:)
        @connection = connection
        @devices = ResourceMapper.new(@connection)
        @stdout = @devices.connect_device("stdout")
        @stdin = @devices.connect_device("stdin")
        @stderr = @devices.connect_device("stderr")
        @browser = @devices.connect_device("browser")
        @file = @devices.connect_device("file")

        if block_given?
          begin
            yield self
          ensure
            exit
          end
        end
      end

      def exec(&shell)
        instance_eval(&shell)
      ensure
        exit
      end

      def exit(status = 0)
        @connection.write(event: "exit", status: status)
      end

      def close
        @connection.close
      end
    end

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
        logger.info "Socket: Sistening..."
        loop do
          client_socket = @server_socket.accept
          logger.debug "Socket: Client #{client_socket.inspect} connected"
          handle_client(client_socket)
        end
      end

      private

      def handle_client(socket)
        transport = Transport::Socket.new(socket)
        connection = Connection.new(transport)

        Thread.new do
          handler = Handler.new(connection)
          handler.run
        end
      end
    end

    class Handler
      include Logging

      def initialize(connection)
        @connection = connection
      end

      def run
        logger.info "Server Handler: Running"
        loop do
          message = @connection.recv
          case message
          in { event: "initialize", arguments:, program_name: }
            Session.new(connection: @connection) do |session|
              MyCLI.start(arguments, session: session)
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET
        logger.info "Server Handler: Client disconnected"
      ensure
        @connection.close
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