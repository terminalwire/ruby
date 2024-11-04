require "async/http/internet"
require "base64"
require "uri"
require "fileutils"

module Terminalwire::Client
  # Checkes the server for a license verification at `https://terminalwire.com/licenses/verifications/`
  # and displays the message to the user, if necessary.
  class ServerLicenseVerification
    include Terminalwire::Logging

    def initialize(url:)
      @url = URI(url)
      @internet = Async::HTTP::Internet.new
      @cache_store = Terminalwire::Cache::File::Store.new(path: Terminalwire::Client.root_path.join("cache/licenses/verifications"))
    end

    def key
      Base64.urlsafe_encode64 @url
    end

    def cache = @cache_store.entry key

    def payload
      if cache.miss?
        logger.debug "Stale verification. Requesting new verification."
        request do |response|
          # Set the expiry on the file cache for the header.
          if max_age = response.headers["cache-control"].max_age
            logger.debug "Caching for #{max_age}"
            cache.expires = Time.now + max_age
          end

          # Process based on the response code.
          case response.status
          in 200
            logger.debug "License for #{@url} found."
            data = self.class.unpack response.read
            cache.value = data
            return data
          in 404
            logger.debug "License for #{@url} not found."
            return self.class.unpack response.read
          end
        end
      else
        return cache.value
      end
    end

    def message
      payload.dig(:shell, :output)
    end

    protected

    def verification_url
      Terminalwire.url
        .path("/licenses/verifications", key)
    end

    def request(&)
      logger.debug "Requesting license verification from #{verification_url}."
      response = @internet.get verification_url, {
        "Accept" => "application/x-msgpack",
        "User-Agent" => "Terminalwire/#{Terminalwire::VERSION} Ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})",
      }, &
    end

    def self.unpack(pack)
      MessagePack.unpack(pack, symbolize_keys: true)
    end
  end
end
