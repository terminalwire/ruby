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
    loader.ignore("#{__dir__}/generators")
    loader.setup
  end

  module Logging
    DEVICE = Logger.new($stdout, level: ENV.fetch("LOG_LEVEL", "info"))
    def logger = DEVICE
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
      logger.debug "Connection: Received #{data.inspect}"
      data
    end

    def close
      @transport.close
    end
  end

  class ResourceRegistry
    def initialize
      @resources = {}
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
      attr_reader :name, :connection

      def initialize(name, connection)
        @name = name.to_s
        @connection = connection
      end

      def connect; end
      def dispatch(action, data); end
      def disconnect; end

      def respond(response, status: :success)
        connection.write(event: "device", name: @name, status:, response:)
      end

      def self.protocol_key
        name.split("::").last.downcase
      end
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

  module Server
    module Resource
      class Base < Terminalwire::Resource::Base
        private

        def command(command, **parameters)
          @connection.write(event: "device", name: @name, action: "command", command: command, **parameters)
          @connection.recv&.fetch(:response)
        end
      end

      class IO < Base
        def puts(data)
          command("print_line", data: data)
        end

        def print(data)
          command("print", data: data)
        end

        def gets
          command("gets")
        end

        def flush
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

      class File < Base
        def read(path)
          command("read", path.to_s)
        end

        def write(path, content)
          command("write", path: path.to_s, content:)
        end

        def append(path, content)
          command("append", path: path.to_s, content:)
        end

        def mkdir(path)
          command("mkdir", path: path.to_s)
        end

        def exist?(path)
          command("exist", path: path.to_s)
        end
      end

      class Browser < Base
        def launch(url)
          command("launch", url: url)
        end
      end
    end

    class ResourceMapper
      include Logging

      def initialize(connection)
        @devices = {}
        @connection = connection
      end

      def connect(resource)
        type = resource.name
        logger.debug "Server: Requesting client to connect device #{type}"
        @connection.write(event: "device", action: "connect", name: type, type: type)
        response = @connection.recv
        case response
        in { status: "success" }
          logger.debug "Server: Resource #{type} connected."
          @devices[type] = resource
        else
          logger.debug "Server: Failed to connect device #{type}."
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
        @stdout = @devices.connect Server::Resource::STDOUT.new("stdout", @connection)
        @stdin = @devices.connect Server::Resource::STDIN.new("stdin", @connection)
        @stderr = @devices.connect Server::Resource::STDERR.new("stderr", @connection)
        @browser = @devices.connect Server::Resource::Browser.new("browser", @connection)
        @file = @devices.connect Server::Resource::File.new("file", @connection)

        if block_given?
          begin
            yield self
          ensure
            exit
          end
        end
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

  module Client
    module Resource
      class Base < Terminalwire::Resource::Base
        def dispatch(command, data)
          respond self.public_send(command, **data)
        end
      end

      class STDOUT < Base
        def connect
          @device = $stdout
        end

        def print(data:)
          @device.print(data)
        end

        def print_line(data:)
          @device.puts(data)
        end
      end

      class STDERR < STDOUT
        def connect
          @device = $stderr
        end
      end

      class STDIN < Base
        def connect
          @device = $stdin
        end

        def gets
          @device.gets
        end

        def getpass
          @device.getpass
        end
      end

      class File < Base
        File = ::File

        def read(data:)
          File.read File.expand_path(data)
        end

        def write(path:, content:)
          File.open(File.expand_path(path), "w") { |f| f.write(content) }
        end

        def append(path:, content:)
          File.open(File.expand_path(path), "a") { |f| f.write(content) }
        end

        def mkdir(path:)
          FileUtils.mkdir_p(File.expand_path(path))
        end

        def exist(path:)
          File.exist? File.expand_path(path)
        end
      end

      class Browser < Base
        def launch(url:)
          Launchy.open(URI(url))
          nil
        end
      end
    end

    class ResourceMapper
      def initialize(connection, resources)
        @connection = connection
        @resources = resources
        @devices = {}
      end

      def connect_device(type)
        klass = @resources.find(type)
        if klass
          device = klass.new(type, @connection)
          device.connect
          @devices[type] = device
          @connection.write(event: "device", action: "connect", status: "success", name: type, type: type)
        else
          @connection.write(event: "device", action: "connect", status: "failure", name: type, type: type, message: "Unknown device type")
        end
      end

      def dispatch(name, action, data)
        device = @devices[name]
        if device
          device.dispatch(action, data)
        else
          raise "Unknown device: #{name}"
        end
      end

      def disconnect_device(name)
        device = @devices.delete(name)
        device&.disconnect
        @connection.write(event: "device", action: "disconnect", name: name)
      end
    end

    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      attr_reader :arguments, :program_name

      def initialize(connection, resources = self.class.resources, arguments: ARGV, program_name: $0)
        @connection = connection
        @resources = resources
        @arguments = arguments
        @program_name = program_name
      end

      def connect
        @devices = ResourceMapper.new(@connection, @resources)

        @connection.write(event: "initialize", protocol: { version: VERSION }, arguments:, program_name:)

        loop do
          handle @connection.recv
        end
      end

      def handle(message)
        case message
        in { event: "device", action: "connect", name:, type: }
          @devices.connect_device(type)
        in { event: "device", action: "command", name:, command:, **data }
          @devices.dispatch(name, command, data)
        in { event: "device", action: "disconnect", name: }
          @devices.disconnect_device(name)
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

    def self.websocket(url:, arguments: ARGV)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(url)

        Async::WebSocket::Client.connect(endpoint) do |connection|
          transport = Terminalwire::Transport::WebSocket.new(connection)
          connection = Terminalwire::Connection.new(transport)
          Terminalwire::Client::Handler.new(connection, arguments:).connect
        end
      end
    end
  end
end
