require 'msgpack'

module Terminalwire
  class Adapter
    include Logging

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
end
