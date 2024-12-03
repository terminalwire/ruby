# frozen_string_literal: true

require "terminalwire-core"
require "terminalwire-server"
require "terminalwire-client"
require "terminalwire"
require "pathname"
require "uri"

# This will smoke out more bugs that could come up in environments like
# Rails.
require "zeitwerk"
Zeitwerk::Loader.eager_load_all

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec.configure do |config|
  config.around(:each) do |example|
    Dir.mktmpdir do |tmp_dir|
      original_terminalwire_home = ENV['TERMINALWIRE_HOME']
      begin
        ENV['TERMINALWIRE_HOME'] = tmp_dir
        example.run
      ensure
        ENV['TERMINALWIRE_HOME'] = original_terminalwire_home
      end
    end
  end
end
