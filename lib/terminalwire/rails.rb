require 'jwt'
require 'pathname'
require 'forwardable'

module Terminalwire::Rails
  class Session
    FILENAME = "session.jwt"

    extend Forwardable

    # Delegate `dig` and `fetch` to the `read` method
    def_delegators :read,
      :dig, :fetch

    def initialize(context:, path: nil, secret_key: self.class.secret_key)
      @context = context
      @path = path || context.storage_path
      @config_file_path = @path.join(FILENAME)
      @secret_key = secret_key

      ensure_file
    end

    def read
      jwt_token = @context.file.read(@config_file_path)
      decoded_data = JWT.decode(jwt_token, @secret_key, true, algorithm: 'HS256')
      decoded_data[0]  # JWT payload is the first element in the array
    rescue JWT::DecodeError => e
      raise "Invalid or tampered file: #{e.message}"
    end

    def edit
      config = read
      yield config
      write(config)
    end

    def write(config)
      token = JWT.encode(config, @secret_key, 'HS256')
      @context.file.write(@config_file_path, token)
    end

    private

    def ensure_file
      return if @context.file.exist? @config_file_path
      @context.file.mkdir(@path) unless @context.file.exist?(@path)
      write({})  # Write an empty configuration on initialization
    end

    def self.secret_key
      Rails.application.secret_key_base
    end
  end
end
