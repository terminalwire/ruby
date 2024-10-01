require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"
require "socket"
require "pathname"

RSpec.describe "Terminalwire Install", type: :system do
  let(:binary_name) { "hello" }
  let(:gem_path) { File.expand_path('../../../', __FILE__) }
  let(:exe_path)  { File.join(gem_path, "exe") }

  before(:all) do
    # Set up the Rails app once for this test suite
    @test_app_path = Dir.mktmpdir
    @gem_path = File.expand_path('../../../', __FILE__)
    @exe_path = File.join(@gem_path, "exe")

    # Remove any existing test app
    # TODO: We need to have a TERMINALWIRE_HOME env var to set this root.
    begin
      FileUtils.remove_entry(File.expand_path("~/.terminalwire/authorities/localhost:3000"))
    rescue
      puts "No existing test app to remove."
    end

    @original_path = Dir.pwd
    Dir.chdir(@test_app_path)

    Bundler.with_unbundled_env do
      ENV["PATH"] = "#{@exe_path}:#{ENV["PATH"]}"

      # Create a bare Rails app
      system("rails new . --minimal --skip-bundle")

      # Add the terminalwire gem to the Gemfile
      system("bundle add terminalwire --path #{@gem_path}")

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

            def initialize(email)
              @email = email
            end
            alias :id :email

            def self.authenticate(email, password)
              new email
            end

            def self.find(email)
              new email
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

    FileUtils.remove_entry(@test_app_path)
  end

  it "runs Terminalwire client against server" do
    # Run the binary and capture output
    output, status = Open3.capture2e("bin/#{binary_name} hello World")
    expect(output.strip).to eql "Hello World"
    expect(status).to be_success
  end


  it "logs in successfully" do
    Open3.popen3("bin/#{binary_name} login") do |stdin, stdout, stderr, wait_thr|
      # Simulate entering email and password
      stdin.puts "brad@example.com"
      stdin.puts "password123"

      output = stdout.read

      binding.irb

      # Ensure the correct output
      expect(output).to include("Successfully logged in as.")

      # Ensure email is visible
      expect(output).to include("brad@example.com")

      # Ensure password is not visible
      expect(output).not_to include("password123")

      # Ensure the process was successful
      expect(wait_thr.value).to be_success
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
