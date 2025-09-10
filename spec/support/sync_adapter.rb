# frozen_string_literal: true

# Synchronous adapter that directly connects server and client resources
# for testing without WebSocket/async complexity
class SyncAdapter
  def initialize
    @client_handler = nil
    @server_response = nil
    @client_adapter = SyncClientAdapter.new(self)
  end

  # Connect the client handler that will process messages
  def connect_client(client_handler)
    @client_handler = client_handler
  end

  # Get the adapter that client resources should use
  def client_adapter
    @client_adapter
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

  # Inner class for client-side adapter
  class SyncClientAdapter
    def initialize(sync_adapter)
      @sync_adapter = sync_adapter
    end

    # Client resources call this through respond method
    def write(**response)
      @sync_adapter.store_response(**response)
    end
  end
end