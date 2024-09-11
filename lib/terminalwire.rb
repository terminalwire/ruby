# frozen_string_literal: true

require_relative "terminalwire/version"

require 'socket'
require 'msgpack'
require 'launchy'
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

  module Resource
    class Base
      attr_reader :name, :adapter

      def initialize(name, adapter)
        @name = name.to_s
        @adapter = adapter
      end

      def connect; end
      def dispatch(action, data); end
      def disconnect; end

      def respond(response = nil, status: "success")
        adapter.write(event: "device", name: @name, status:, response:)
      end

      def fail(status: "fail", response:)
        adapter.write(event: "device", name: @name, status:, response:)
      end

      def self.protocol_key
        name.split("::").last.downcase
      end
    end
  end
end
