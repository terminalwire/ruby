require 'fileutils'
require 'launchy'
require 'io/console'

module Terminalwire
  module Client
    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      attr_reader :adapter, :resources, :endpoint
      attr_accessor :entitlement

      def initialize(adapter, arguments: ARGV, program_name: $0, endpoint:)
        @endpoint = endpoint
        @adapter = adapter
        @program_arguments = arguments
        @program_name = program_name
        @entitlement = Entitlement.resolve(authority: @endpoint.authority)

        yield self if block_given?

        @resources = Resource::Handler.new do |it|
          it << Resource::STDOUT.new("stdout", @adapter, entitlement:)
          it << Resource::STDIN.new("stdin", @adapter, entitlement:)
          it << Resource::STDERR.new("stderr", @adapter, entitlement:)
          it << Resource::Browser.new("browser", @adapter, entitlement:)
          it << Resource::File.new("file", @adapter, entitlement:)
          it << Resource::Directory.new("directory", @adapter, entitlement:)
        end
      end

      def verify_license
        # Connect to the Terminalwire license server to verify the URL endpoint
        # and displays a message to the user, if any are present.
        $stdout.print Terminalwire::Client::ServerLicenseVerification.new(url: @endpoint.to_url).message
      rescue
        $stderr.puts "Failed to verify server license."
      end

      def connect
        verify_license

        @adapter.write(
          event: "initialization",
          protocol: { version: VERSION },
          entitlement: @entitlement.serialize,
          program: {
            name: @program_name,
            arguments: @program_arguments
          }
        )

        loop do
          handle @adapter.read
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

    def self.websocket(url:, arguments: ARGV, &configuration)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(
          url,
          alpn_protocols: Async::HTTP::Protocol::HTTP11.names
        )

        Async::WebSocket::Client.connect(endpoint) do |adapter|
          transport = Terminalwire::Transport::WebSocket.new(adapter)
          adapter = Terminalwire::Adapter::Socket.new(transport)
          Terminalwire::Client::Handler.new(adapter, arguments:, endpoint:, &configuration).connect
        end
      end
    end
  end
end
