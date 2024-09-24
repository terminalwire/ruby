require 'msgpack'

module Terminalwire::Adapter
  # Works with TCP, Unix, WebSocket, and other socket-like abstractions.
  class Socket
    include Terminalwire::Logging

    attr_reader :transport

    def initialize(transport)
      @transport = transport
    end

    def write(data)
      logger.debug "Adapter: Sending #{data.inspect}"
      packed_data = MessagePack.pack(data, symbolize_keys: true)
      @transport.write(packed_data)
    end

    def recv
      logger.debug "Adapter: Reading"
      packed_data = @transport.read
      return nil if packed_data.nil?
      data = MessagePack.unpack(packed_data, symbolize_keys: true)
      logger.debug "Adapter: Received #{data.inspect}"
      data
    end

    def close
      @transport.close
    end
  end

  # This is a test adapter that can be used for testing purposes.
  class Test
    attr_reader :responses

    def initialize(responses = [])
      @responses = responses
    end

    def write(**data)
      @responses << data
    end

    def response
      @responses.pop
    end

    def close
    end
  end
end
