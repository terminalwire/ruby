require 'terminalwire'

require 'launchy'
require 'io/console'
require 'pathname'

require 'forwardable'
require 'uri'

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'async/websocket/adapters/rack'
require 'uri-builder'

require "zeitwerk"
Zeitwerk::Loader.for_gem_extension(Terminalwire).tap do |loader|
  loader.setup
end

module Terminalwire
  module Client
    ROOT_PATH = "~/.terminalwire".freeze
    def self.root_path = Pathname.new(ENV.fetch("TERMINALWIRE_HOME", ROOT_PATH))

    def self.websocket(url:, arguments: ARGV, &configuration)
      ENV["TERMINALWIRE_HOME"] ||= root_path.to_s

      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(
          url,
          alpn_protocols: Async::HTTP::Protocol::HTTP11.names
        )

        Async::WebSocket::Client.connect(endpoint) do |connection|
          transport = Terminalwire::Transport::WebSocket.new(connection)
          adapter = Terminalwire::Adapter::Socket.new(transport)
          Terminalwire::Client::Handler.new(adapter, arguments:, endpoint:, &configuration).connect
        end
      end
    end
  end
end
