# frozen_string_literal: true

require_relative "terminalwire/version"

require 'forwardable'
require 'uri'

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'async/websocket/adapters/rack'
require 'uri-builder'

require "zeitwerk"
Zeitwerk::Loader.for_gem.tap do |loader|
  loader.ignore File.join(__dir__, "terminalwire-core.rb")
  loader.setup
end

module Terminalwire
  class Error < StandardError; end

  # Used by Terminalwire client to connect to Terminalire.com for license
  # validations, etc.
  TERMINALWIRE_URL = "https://terminalwire.com".freeze
  def self.url = URI.build(TERMINALWIRE_URL)

  # Fiber/Task-local request context to propagate message id.
  module Request
    KEY = :terminalwire_request_id

    # Return the current request id from the Async::Task or Fiber-local storage.
    def self.current_id
      if (task = Async::Task.current?)
        task[KEY]
      elsif Fiber.respond_to?(:[])
        Fiber[:terminalwire_request_id]
      else
        nil
      end
    end

    # Execute the given block with the request id bound in the current task/fiber.
    def self.with_id(id)
      if (task = Async::Task.current?)
        previous = task[KEY]
        task[KEY] = id
        begin
          yield
        ensure
          task[KEY] = previous
        end
      elsif Fiber.respond_to?(:[]=)
        previous = Fiber[:terminalwire_request_id]
        Fiber[:terminalwire_request_id] = id
        begin
          yield
        ensure
          Fiber[:terminalwire_request_id] = previous
        end
      else
        yield
      end
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
      def disconnect; end

      def fail(response, **data)
        respond(status: "failure", response:, **data)
      end

      def succeed(response, **data)
        respond(status: "success", response:, **data)
      end

      private

      def respond(**response)
        payload = {event: "resource", name: @name, **response}
        if (id = Terminalwire::Request.current_id)
          payload[:id] = id
        end
        adapter.write(payload)
      end
    end
  end
end
