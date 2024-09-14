require 'jwt'
require 'pathname'
require 'forwardable'

module Terminalwire::Rails
  class Cookie
    FILENAME = "config.jwt"

    extend Forwardable

    # Delegate `dig` and `fetch` to the `read` method
    def_delegators :read, :dig, :fetch

    def initialize(path: nil, session:, secret_key: self.class.secret_key)
      @session = session
      @path = path || session.storage_path
      @config_file_path = @path.join(FILENAME)
      @secret_key = secret_key

      ensure_file
    end

    def read
      jwt_token = @session.file.read(@config_file_path)
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
      @session.file.write(@config_file_path, token)
    end

    private

    def ensure_file
      return if @session.file.exist? @config_file_path
      @session.file.mkdir(@path) unless @session.file.exist?(@path)
      write({})  # Write an empty configuration on initialization
    end

    def self.secret_key
      Rails.application.secret_key_base
    end
  end
end
