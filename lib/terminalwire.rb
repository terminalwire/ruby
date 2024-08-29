# frozen_string_literal: true

require_relative "terminalwire/version"

require 'socket'
require 'msgpack'
require 'launchy'
require 'logger'
require 'io/console'
require 'forwardable'
require 'uri'
require 'zeitwerk'

require 'thor'
require 'fileutils'

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'async/websocket/adapters/rack'

module Terminalwire
  class Error < StandardError; end

  Loader = Zeitwerk::Loader.for_gem.tap do |loader|
    loader.setup
  end

  module Logging
    DEVICE = Logger.new($stdout, level: ENV.fetch("LOG_LEVEL", "info"))
    def logger = DEVICE
  end

  module Thor
    class Shell < ::Thor::Shell::Basic
      extend Forwardable

      # Encapsulates all of the IO devices for a Terminalwire connection.
      attr_reader :session

      def_delegators :@session, :stdin, :stdout, :stderr

      def initialize(session)
        @session = session
        super()
      end
    end

    def self.included(base)
      base.extend ClassMethods

      # I have to do this in a block to deal with some of Thor's DSL
      base.class_eval do
        extend Forwardable

        protected

        no_commands do
          def_delegators :shell, :session
          def_delegators :session, :stdout, :stdin, :stderr, :browser
          def_delegators :stdout, :puts, :print
          def_delegators :stdin, :gets
        end
      end
    end

    module ClassMethods
      def start(given_args = ARGV, config = {})
        session = config.delete(:session)
        config[:shell] = Shell.new(session) if session
        super(given_args, config)
      end
    end
  end

  module Transport
    class Base
      def initialize
        raise NotImplementedError, "This is an abstract base class"
      end

      def read
        raise NotImplementedError, "Subclass must implement #read"
      end

      def write(data)
        raise NotImplementedError, "Subclass must implement #write"
      end

      def close
        raise NotImplementedError, "Subclass must implement #close"
      end
    end

    class WebSocket
      def initialize(websocket)
        @websocket = websocket
      end

      def read
        @websocket.read&.buffer
      end

      def write(data)
        @websocket.write(data)
      end

      def close
        @websocket.close
      end
    end

    class Socket < Base
      def initialize(socket)
        @socket = socket
      end

      def read
        length = @socket.read(4)
        return nil if length.nil?
        length = length.unpack('L>')[0]
        @socket.read(length)
      end

      def write(data)
        length = [data.bytesize].pack('L>')
        @socket.write(length + data)
      end

      def close
        @socket.close
      end
    end
  end

  class Connection
    include Logging

    attr_reader :transport

    def initialize(transport)
      @transport = transport
    end

    def write(data)
      logger.debug "Connection: Sending #{data.inspect}"
      packed_data = MessagePack.pack(data, symbolize_keys: true)
      @transport.write(packed_data)
    end

    def recv
      logger.debug "Connection: Reading"
      packed_data = @transport.read
      return nil if packed_data.nil?
      data = MessagePack.unpack(packed_data, symbolize_keys: true)
      logger.debug "Connection: Recieved #{data.inspect}"
      data
    end

    def close
      @transport.close
    end
  end

  class ResourceRegistry
    def initialize
      @resources = Hash.new
    end

    def register(name, to: nil)
      @resources[name.to_s] = to
    end

    def <<(resource_class)
      register resource_class.protocol_key, to: resource_class
    end

    def find(name)
      @resources.fetch(name.to_s)
    end
  end

  module Resource
    class Base
      attr_reader :id, :connection

      def initialize(id, connection)
        @id = Integer(id)
        @connection = connection
      end

      def connect; end
      def dispatch(action, data); end
      def disconnect; end

      def respond(response, status: :success)
        connection.write(event: "device", id: @id, status:, response:)
      end

      def self.protocol_key
        name.split("::").last.downcase
      end
    end
  end

  module Client
    module Resource
      class IO < Terminalwire::Resource::Base
        def dispatch(action, data)
          if @device.respond_to?(action)
            respond @device.public_send(action, data)
          else
            raise "Unknown action #{action} for device ID #{@id}"
          end
        end
      end

      class STDOUT < IO
        def connect
          @device = $stdout
        end
      end

      class STDIN < IO
        def connect
          @device = $stdin
        end

        def dispatch(action, data)
          respond case action
          when "puts"
            @device.puts(data)
          when "gets"
            @device.gets
          when "getpass"
            @device.getpass
          end
        end
      end

      class STDERR < IO
        def connect
          @device = $stderr
        end
      end

      class File < Terminalwire::Resource::Base
        def connect
          @files = {}
        end

        def dispatch(action, data)
          respond case action
          when "read"
            read_file(data)
          when "write"
            write_file(data.fetch(:path), data.fetch(:content))
          when "append"
            append_to_file(data.fetch(:path), data.fetch(:content))
          when "mkdir"
            mkdir(data.fetch(:path))
          when "exist"
            exist?(data.fetch(:path))
          else
            raise "Unknown action #{action} for file device"
          end
        end

        def mkdir(path)
          FileUtils.mkdir_p(::File.expand_path(path))
        end

        def exist?(path)
          ::File.exist? ::File.expand_path(path)
        end

        def read_file(path)
          ::File.read ::File.expand_path(path)
        end

        def write_file(path, content)
          ::File.open(::File.expand_path(path), "w") { |f| f.write(content) }
        end

        def append_to_file(path, content)
          ::File.open(::File.expand_path(path), "a") { |f| f.write(content) }
        end

        def disconnect
          @files.clear
        end
      end

      class Browser < Terminalwire::Resource::Base
        def dispatch(action, data)
          respond case action
          when "launch"
            Launchy.open(data)
            "Launched browser with URL: #{data}"
          else
            raise "Unknown action #{action} for browser device"
          end
        end
      end
    end

    class ResourceMapper
      def initialize(connection, resources)
        @connection = connection
        @resources = resources
        @devices = Hash.new { |h,k| h[Integer(k)] }
      end

      def connect_device(id, type)
        klass = @resources.find(type)
        if klass
          device = klass.new(id, @connection)
          device.connect
          @devices[id] = device
          @connection.write(event: "device", action: "connect", status: "success", id: id, type: type)
        else
          @connection.write(event: "device", action: "connect", status: "failure", id: id, type: type, message: "Unknown device type")
        end
      end

      def dispatch(id, action, data)
        device = @devices[id]
        if device
          device.dispatch(action, data)
        else
          raise "Unknown device ID: #{id}"
        end
      end

      def disconnect_device(id)
        device = @devices.delete(id)
        device&.disconnect
        @connection.write(event: "device", action: "disconnect", id: id)
      end
    end

    class Handler
      include Logging

      def initialize(connection, resources = self.class.resources)
        @connection = connection
        @resources = resources
      end

      def connect
        @devices = ResourceMapper.new(@connection, @resources)

        @connection.write(event: "initialize", protocol: { version: "0.1.0" }, arguments: ARGV, program_name: $0)

        loop do
          handle @connection.recv
        end
      end

      def handle(message)
        case message
        in { event: "device", action: "connect", id:, type: }
          @devices.connect_device(id, type)
        in { event: "device", action: "command", id:, command:, data: }
          @devices.dispatch(id, command, data)
        in { event: "device", action: "disconnect", id: }
          @devices.disconnect_device(id)
        in { event: "exit", status: }
          exit Integer(status)
        end
      end

      def self.resources
        ResourceRegistry.new.tap do |resources|
          resources << Client::Resource::STDOUT
          resources << Client::Resource::STDIN
          resources << Client::Resource::STDERR
          resources << Client::Resource::Browser
          resources << Client::Resource::File
        end
      end
    end

    def self.tcp(...)
      socket = TCPSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      connection = Terminalwire::Connection.new(transport)
      Terminalwire::Client::Handler.new(connection)
    end

    def self.socket(...)
      socket = UNIXSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      connection = Terminalwire::Connection.new(transport)
      Terminalwire::Client::Handler.new(connection)
    end

    def self.websocket(url)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(url)

        Async::WebSocket::Client.connect(endpoint) do |connection|
          transport = Terminalwire::Transport::WebSocket.new(connection)
          connection = Terminalwire::Connection.new(transport)
          Terminalwire::Client::Handler.new(connection).connect
        end
      end
    end
  end

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

  module WebSocket
    class Server
      include Logging

      def call(env)
        Async::WebSocket::Adapters::Rack.open(env, protocols: ['ws']) do |connection|
          run(Connection.new(Terminalwire::Transport::WebSocket.new(connection)))
        end or [200, { "Content-Type" => "text/plain" }, ["Connect via WebSockets"]]
      end

      private

      def run(connection)
        while message = connection.recv
          puts message
        end
      end
    end

    class ThorServer < Server
      include Logging

      def initialize(cli_class)
        @cli_class = cli_class

        # Check if the Terminalwire::Thor module is already included
        unless @cli_class.included_modules.include?(Terminalwire::Thor)
          raise 'Add `include Terminalwire::Thor` to the #{@cli_class.inspect} class.'
        end
      end

      def run(connection)
        logger.info "ThorServer: Running #{@cli_class.inspect}"
        while message = connection.recv
          case message
          in { event: "initialize", protocol: { version: _ }, arguments:, program_name: }
            Terminalwire::Server::Session.new(connection: connection) do |session|
              @cli_class.start(arguments, session: session)
            end
          end
        end
      end
    end
  end
end