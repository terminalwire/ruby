# frozen_string_literal: true

module Sync
  # Integration helper that sets up synchronized server-client communication for testing
  class Integration
    attr_reader :server_adapter, :client_adapter, :policy

    def initialize(authority: 'test.example.com')
      @server_adapter = Sync::Server::Adapter.new
      @client_adapter = Sync::Client::Adapter.new(@server_adapter)
      @policy =  Terminalwire::Client::Entitlement::Policy.resolve(authority:)
      @client_handler = nil

      yield self if block_given?

      @client_handler = Terminalwire::Client::Resource::Handler.new(
        adapter: @client_adapter,
        entitlement: policy
      )

      @server_adapter.connect_client(@client_handler)
    end

    private

    def setup_client_handler
      @client_handler = Terminalwire::Client::Resource::Handler.new(
        adapter: @client_adapter,
        entitlement: policy
      )
      @server_adapter.connect_client(@client_handler)
    end
  end

  module Server
    # Server-side adapter for synchronous testing
    class Adapter
      def initialize
        @client_handler = nil
        @server_response = nil
      end

      # Connect the client handler that will process messages
      def connect_client(client_handler)
        @client_handler = client_handler
      end

      # Server writes message to adapter (request)
      def write(**message)
        raise "No client handler connected" unless @client_handler

        # Clear previous response
        @server_response = nil

        # Directly dispatch message to client handler
        # Client will process and call succeed/fail, which will store response
        @client_handler.dispatch(**message)
      end

      # Server reads response from adapter
      def read
        @server_response || raise("No response available")
      end

      # Called by client adapter when client responds
      def store_response(**response)
        @server_response = response
      end
    end
  end

  module Client
    # Client-side adapter for synchronous testing
    class Adapter
      def initialize(server_adapter)
        @server_adapter = server_adapter
      end

      # Client resources call this through respond method
      def write(**response)
        @server_adapter.store_response(**response)
      end
    end
  end
end

