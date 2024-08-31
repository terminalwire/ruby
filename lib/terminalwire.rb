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