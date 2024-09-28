require 'fileutils'
require 'launchy'
require 'io/console'

module Terminalwire
  module Client
    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      attr_reader :adapter, :entitlement, :resources

      def initialize(adapter, arguments: ARGV, program_name: $0, entitlement:)
        @entitlement = entitlement
        @adapter = adapter
        @program_arguments = arguments
        @program_name = program_name

        FileUtils.mkdir_p entitlement.storage_path.expand_path

        @resources = Resource::Handler.new do |it|
          it << Resource::STDOUT.new("stdout", @adapter, entitlement:)
          it << Resource::STDIN.new("stdin", @adapter, entitlement:)
          it << Resource::STDERR.new("stderr", @adapter, entitlement:)
          it << Resource::Browser.new("browser", @adapter, entitlement:)
          it << Resource::File.new("file", @adapter, entitlement:)
          it << Resource::Directory.new("directory", @adapter, entitlement:)
        end
      end

      def connect
        @adapter.write(event: "initialization",
         protocol: { version: VERSION },
         entitlement: @entitlement.serialize,
         program: {
           name: @program_name,
           arguments: @program_arguments
         })

        loop do
          handle @adapter.recv
        end
      end

      def handle(message)
        case message
        in { event: "resource", action: "command", name:, parameters: }
          @resources.dispatch(**message)
        in { event: "exit", status: }
          exit Integer(status)
        end
      end
    end

    def self.tcp(...)
      socket = TCPSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      adapter = Terminalwire::Adapter::Socket.new(transport)
      Terminalwire::Client::Handler.new(adapter)
    end

    def self.socket(...)
      socket = UNIXSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      adapter = Terminalwire::Adapter::Socket.new(transport)
      Terminalwire::Client::Handler.new(adapter)
    end

    # Extracted from HTTP. This is so we can
    def self.authority(url)
      if url.port == url.default_port
        url.host
      else
        "#{url.host}:#{url.port}"
      end
    end

    def self.websocket(url:, arguments: ARGV, entitlement: nil)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(
          url,
          alpn_protocols: Async::HTTP::Protocol::HTTP11.names
        )

        Async::WebSocket::Client.connect(endpoint) do |adapter|
          transport = Terminalwire::Transport::WebSocket.new(adapter)
          adapter = Terminalwire::Adapter::Socket.new(transport)
          entitlement ||= Entitlement.from_url(url)
          Terminalwire::Client::Handler.new(adapter, arguments:, entitlement:).connect
        end
      end
    end
  end
end
