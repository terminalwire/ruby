require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"
require "pathname"
require "pty"
require "io/wait"

RSpec.describe "Terminalwire Install", type: :system do
  let(:binary_name) { "hello" }
  let(:gem_path) { File.expand_path('../../../gem/terminalwire', __FILE__) }
  let(:exe_path)  { File.join(gem_path, "exe") }

  before(:all) do
    # Set up the Rails app once for this test suite
    @test_app_path = Dir.mktmpdir
    @gem_path = File.expand_path('../../../gem/terminalwire', __FILE__)
    @exe_path = File.join(@gem_path, "exe")
    @terminalwire_path = File.join(@test_app_path, ".terminalwire")

    @server_gem_path = File.expand_path('../../../gem/terminalwire-server', __FILE__)
    @rails_gem_path = File.expand_path('../../../gem/terminalwire-rails', __FILE__)

    @original_path = Dir.pwd
    Dir.chdir(@test_app_path)

    @oringal_path = ENV["PATH"]
    ENV["PATH"] = "#{@exe_path}:#{ENV["PATH"]}"

    Bundler.with_unbundled_env do
      # Create a bare Rails app
      system("rails new . --minimal --skip-bundle")

      # Add the terminalwire gem to the Gemfile
      system("bundle add terminalwire --path #{@gem_path}")
      system("bundle add terminalwire-server --path #{@server_gem_path}")
      system("bundle add terminalwire-rails --path #{@rails_gem_path}")

      # Run the terminalwire install generator
      system("bin/rails generate terminalwire:install hello")

      # Boot the Puma server in the background
      @pid = spawn("bin/rails server -b 0.0.0.0 -p 3000")

      # Create a User class with an authenticate method.
      File.write(
        "app/models/user.rb",
        <<~RUBY
          class User
            attr_reader :email

            def initialize(email:)
              @email = email
            end
            alias :id :email

            def valid_password?(password)
              true
            end

            def self.find_for_authentication(email:)
              find email
            end

            def self.find(email)
              new email: email
            end
          end
        RUBY
      )

      # Poll until the server is ready
      wait_for_server("0.0.0.0", 3000)
    end
  end

  after(:all) do
    Dir.chdir(@original_path)

    # Clean up after the tests are finished
    if @pid
      Process.kill("TERM", @pid)
      Process.wait(@pid)
    end

    # Restore env vars
    ENV["PATH"] = @oringal_path

    FileUtils.remove_entry(@test_app_path)
  end

  it "runs Terminalwire client against server" do
    # Run the binary and capture output
    output, status = Open3.capture2e("bin/#{binary_name} hello World")
    expect(output.strip).to eql "Hello World"
    expect(status).to be_success
  end

  it "logs in successfully" do
    PTY.spawn("bin/#{binary_name} login") do |stdout, stdin, pid|
      # stdout.readpartial("Email: ".size)
      # Simulate entering email and password
      stdin.puts "brad@example.com"

      # stdout.readpartial("Password: ".size)
      stdin.puts "password123"

      output = stdout.read
      expect(output).to include("Successfully logged in as brad@example.com.")

      # Ensure the process was successful
      Process.wait(pid)
      expect($?.success?).to be_truthy
    end
  end

  private

  def wait_for_server(host, port, timeout: 10)
    start_time = Time.now
    until Time.now - start_time > timeout
      begin
        TCPSocket.new(host, port).close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        sleep 0.1
      end
    end
    raise "Server did not start within #{timeout} seconds"
  end
end
