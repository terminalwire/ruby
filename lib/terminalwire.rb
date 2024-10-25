# frozen_string_literal: true

require_relative "terminalwire/version"

require 'socket'
require 'forwardable'
require 'uri'
require 'zeitwerk'

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

  module Resource
    class Base
      attr_reader :name, :adapter

      def initialize(name, adapter)
        @name = name.to_s
        @adapter = adapter
      end

      def connect; end
      def disconnect; end

      def fail(response, **data)
        respond(status: "failure", response:, **data)
      end

      def succeed(response, **data)
        respond(status: "success", response:, **data)
      end

      private

      def respond(**response)
        adapter.write(event: "resource", name: @name, **response)
      end
    end
  end
end
