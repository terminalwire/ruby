# frozen_string_literal: true

require_relative "terminalwire/version"

require 'forwardable'
require 'uri'

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'async/websocket/adapters/rack'
require 'uri-builder'

require_relative "terminalwire/loader"
Terminalwire::Loader.setup do |loader|
  loader.ignore File.join(__dir__, "terminalwire/version.rb")
  loader.ignore File.join(__dir__, "terminalwire/loader.rb")
  loader.ignore File.join(__dir__, "terminalwire-core.rb")
  loader.push_dir File.join(__dir__, "terminalwire"), namespace: Terminalwire
end

module Terminalwire
  class Error < StandardError; end

  # Used by Terminalwire client to connect to Terminalire.com for license
  # validations, etc.
  TERMINALWIRE_URL = "https://terminalwire.com".freeze
  def self.url = URI.build(TERMINALWIRE_URL)

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
