require 'async/http/internet'
require 'msgpack'
require 'base64'

module Terminalwire
  module Client::Endpoint
    class Verifier
      include Logging

      ENDPOINTS_URL = "http://localhost:5400/endpoints".freeze

      attr_reader :url, :internet

      def initialize(url:)
        @url = url
        @internet = Async::HTTP::Internet.new

        # payload = post
        # p unwrap payload
        # payload = put payload
        # p unwrap payload

        @cache = Terminalwire::Cache::File::Store.new(path: "./license-cache")

        entry = @cache.find(url)

        if entry.hit?
          logger.debug "Cache hit #{@url}. Will verify in #{entry.expires - Time.now} seconds on #{entry.expires}."
          return entry.value
        else
          logger.debug "Cache miss #{@url}."

          verify url: do |it|
            if it.body?
              logger.debug "Invalid license."
              puts it.read
            else
              logger.debug "Valid license."
              max_age, visibility = it.headers["cache-control"]
              *, seconds = max_age.partition "="

              entry.expires = Time.now + seconds.to_i
              entry.value = it.read
              entry.save
            end
          end

        end
      end

      def verify(url:)
        verification_url = build_url("http://localhost:5400/licenses/verification", license_verification: { url: })

        response = @internet.get(
          verification_url,
          {
            "Content-Type" => "text/plain",
            "Accept" => "text/plain"
          }
        )
        yield response
      ensure
        response&.close
      end

      def unwrap(payload)
        # Skips the signature verification, since we don't need it client side,
        # and we don't have the private key.
        self.class.unpack(payload) => { data:, signature:, version: }
        self.class.unpack(data)
      end

      def post
        logger.debug "POST"
        internet = Async::HTTP::Internet.new
        response = internet.post(
          ENDPOINTS_URL,
          {
            "Content-Type" => "application/msgpack"
          },
          MessagePack.pack(
            endpoint: {
              version: "1.0",
              url: url.to_s
            }
          )
        )

        response.read
      ensure
        response&.close
      end

      def put(payload)
        logger.debug "PUT"
        response = internet.put(
          ENDPOINTS_URL,
          {
            "Content-Type" => "application/msgpack"
          },
          payload
        )

        response.read
      ensure
        response&.close
      end

      def build_url(*, **)
        URI(*).tap do |it|
          it.query = build_query(**)
        end
      end

      def build_query(params, namespace = nil)
        query = params.filter_map do |key, value|
          next if (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?

          nested_key = namespace ? "#{namespace}[#{key}]" : key.to_s
          if value.is_a?(Hash)
            build_query(value, nested_key)
          elsif value.is_a?(Array)
            value.map { |v| "#{nested_key}[]=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
          else
            "#{nested_key}=#{URI.encode_www_form_component(value.to_s)}"
          end
        end

        query.sort! unless namespace.to_s.include?("[]")
        query.join("&")
      end

      def self.unpack(pack)
        MessagePack.unpack(pack, symbolize_keys: true)
      end
    end
  end
end
