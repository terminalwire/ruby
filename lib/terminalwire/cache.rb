require "pathname"
require "msgpack"
require "base64"
require "time"
require "fileutils"

module Terminalwire::Cache
  module File
    # Hoist the File class to avoid conflicts with the standard library.
    File = ::File

    class Store
      include Enumerable

      def initialize(path:)
        @path = Pathname.new(path)
        FileUtils.mkdir_p(@path) unless @path.directory?
      end

      def find(key)
        Entry.new(path: @path.join(Entry.key_path(key)))
      end
      alias :[] :find

      def evict
        each(&:evict)
      end

      def destroy
        each(&:destroy)
      end

      def each
        @path.each_child do |path|
          yield Entry.new(path:)
        end
      end
    end

    class Entry
      VERSION = "1.0"

      def self.key_path(value)
        Base64.urlsafe_encode64(value)
      end

      attr_accessor :value, :expires

      def initialize(path:)
        @path = path
        deserialize if persisted?
      end

      def nil?
        @value.nil?
      end

      def present?
        not nil?
      end

      def persisted?
        File.exist? @path
      end

      def expired?(time: Time.now)
        @expires && @expires < time.utc
      end

      def fresh?(...)
        not expired?(...)
      end

      def hit?
        persisted? and fresh?
      end

      def miss?
        not hit?
      end

      def save
        File.write @path, serialize
      end

      def evict
        destroy if expired?
      end

      def deserialize
        case MessagePack.unpack(File.read(@path), symbolize_keys: true)
        in { value:, expires:, version: VERSION }
          @value = value
          @expires = Time.parse(expires).utc if expires
        end
      end

      def destroy
        File.delete(@path)
      end

      private

      def serialize
        MessagePack.pack(
          value: @value,
          expires: @expires&.utc&.iso8601,
          version: VERSION
        )
      end
    end
  end
end
