require 'fileutils'
require 'launchy'
require 'io/console'
require 'pathname'

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

        Async::WebSocket::Client.connect(endpoint) do |adapter|
          transport = Terminalwire::Transport::WebSocket.new(adapter)
          adapter = Terminalwire::Adapter::Socket.new(transport)
          Terminalwire::Client::Handler.new(adapter, arguments:, endpoint:, &configuration).connect
        end
      end
    end
  end
end
