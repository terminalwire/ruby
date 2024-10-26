require "msgpack"
require "openssl"
require "base64"
require "uri"

module Terminalwire::Licensing
  PRIVATE_KEY_LENGTH = 2048

  def self.generate_private_key
    OpenSSL::PKey::RSA.new(PRIVATE_KEY_LENGTH)
  end

  def self.generate_private_pem
    generate_private_key.to_pem
  end

  def self.time
    Time.now.utc
  end

  # Handles encoding data into a license key with prefixes that can be packed and unpacked.
  module Key
    # Mix into classes that need to generate or read keys
    module Serialization
      # This is called when the module is included in a class
      def self.included(base)
        # Extend the class with the class methods when the module is included
        base.extend(ClassMethods)
      end

      def serialize(...)
        self.class.serialize(...)
      end

      # Define the class methods that will be available on the including class
      module ClassMethods
        def serializer
          Key::Serializer.new(prefix: self::PREFIX)
        end

        def serialize(...)
          serializer.serialize(...)
        end

        def deserialize(...)
          serializer.deserialize(...)
        end
      end
    end

    class Serializer
      attr_reader :prefix

      def initialize(prefix:)
        @prefix = prefix
      end

      def serialize(data)
        prepend_prefix Base64.urlsafe_encode64 MessagePack.pack data
      end

      def deserialize(data)
        MessagePack.unpack Base64.urlsafe_decode64 unshift_prefix data
      end

      protected

      def prepend_prefix(key)
        [prefix, key].join
      end

      def unshift_prefix(key)
        head, prefix, tail = key.partition(@prefix)
        # Check if partition successfully split the string with the correct prefix
        raise RuntimeError, "Expected prefix #{@prefix.inspect} on #{key.inspect}" if prefix.empty?
        tail
      end
    end
  end

  # This code all runs on Terminalwire servers.
  module Issuer
    # Generates license keys that developers use to activate their software.
    class ServerKeyGenerator
      include Key::Serialization

      PREFIX = "server_key_".freeze

      VERSION = "1.0".freeze

      def initialize(public_key:, license_url:, generated_at: Terminalwire::Licensing.time)
        @public_key = public_key
        @license_url = URI(license_url)
        @generated_at = generated_at
      end

      def to_h
        {
          version: VERSION,
          generated_at: @generated_at.iso8601,
          public_key: @public_key.to_pem,
          license_url: @license_url.to_s
        }
      end

      def server_key
        serialize to_h
      end
      alias :to_s :server_key
    end

    class ClientKeyVerifier
      # Time variance the server will tolerate from the client.
      DRIFT_SECONDS = 600 # 600 seconds, or 10 minutes.

      # This means the server will tolerate a 10 minute drift in the generated_at time.
      def self.drift
        now = Terminalwire::Licensing.time
        (now - DRIFT_SECONDS)...(now + DRIFT_SECONDS)
      end

      def initialize(client_key:, private_key:, drift: self.class.drift)
        @data = Server::ClientKeyGenerator.deserialize client_key
        @private_key = private_key
        @drift = drift
      end

      def server_attestation
        @server_attestation ||= decrypt @data.fetch("server_attestation")
      end

      def decrypt(data)
        MessagePack.unpack @private_key.private_decrypt Base64.urlsafe_decode64 data
      end

      def generated_at
        @generated_at ||= Time.parse(server_attestation.fetch("generated_at"))
      end

      def valid?
        @drift.include? generated_at
      end
    end
  end

  # Those code runs on customer servers
  module Server
    class ClientKeyGenerator
      VERSION = "1.0".freeze

      include Key::Serialization
      PREFIX = "client_key_".freeze

      def initialize(server_key:, generated_at: Terminalwire::Licensing.time)
        @data = Issuer::ServerKeyGenerator.deserialize server_key
        @license_url = URI(@data.fetch("license_url"))
        @generated_at = generated_at
      end

      def to_h
        {
          version: VERSION,
          license_url: @license_url.to_s,
          server_attestation: attest(
            version: VERSION,
            generated_at: @generated_at.iso8601,
          )
        }
      end

      def client_key
        serialize to_h
      end
      alias :to_s :client_key

      protected

      def attest(data)
        Base64.urlsafe_encode64 public_key.public_encrypt MessagePack.pack data
      end

      def public_key
        @public_key ||= OpenSSL::PKey::RSA.new(@data.fetch("public_key"))
      end
    end
  end
end
