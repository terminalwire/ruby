require "async/http/internet"
require "base64"
require "uri"

module Terminalwire
  module Client::Endpoint
    class Verifier
      include Logging

      attr_reader :url, :internet

      Validation = Struct.new(:status, :message)

      def initialize(url:)
        @url = URI(url)
        @internet = Async::HTTP::Internet.new
        @cache_store = Terminalwire::Cache::File::Store.new(path: "~/.terminalwire/cache/licenses")
      end

      def verify
        if cache.hit?
          logger.debug "Cache hit #{@url}. Cache expires at #{cache.expires}."
          Validation.new(:valid, nil)
        else
          logger.debug "Cache miss #{@url}."

          request_verification do |it|
            case it.status
            when 204
              logger.debug "Valid license."
              max_age, visibility = it.headers["cache-control"]
              *, seconds = max_age.partition "="
              logger.debug "Caching valid license for #{seconds} seconds."
              cache.expires = Time.now + Integer(seconds)
              cache.value = it.read
              cache.save

              Validation.new(:valid, nil)
            when 422
              message = it.read
              logger.debug "Invalid license. #{message}"
              Validation.new(:invalid, message)
            else
              Validation.new(
                :error,
                <<~MESSAGE
                  Could not connect to Terminalwire to verify license.

                  Status: #{it.status}

                MESSAGE
              )
            end
          end
        end

      rescue => e
        logger.error "Verification error: #{e.message}"
        Validation.new(:error, "Verification error. Message: #{e.message}")
      end

      protected

      def cache
        @cache_store.find(@url)
      end

      def verification_url
        Terminalwire.url
          .path("/licenses/verification")
          .query(license_verification: { url: })
      end

      def request_verification
        logger.debug "Requesting license verification from #{verification_url}."
        response = @internet.get verification_url, {
          "Accept" => "text/plain",
          "User-Agent" => "Terminalwire/#{Terminalwire::VERSION} Ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})",
        }

        yield response
      ensure
        response&.close
      end
    end
  end
end
