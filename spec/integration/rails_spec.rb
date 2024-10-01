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

    @original_path = Dir.pwd
    Dir.chdir(@test_app_path)

    Bundler.with_unbundled_env do
      ENV["PATH"] = "#{@exe_path}:#{ENV["PATH"]}"

      # Create a bare Rails app
      system("rails new . --minimal --skip-bundle")

      # Add the terminalwire gem to the Gemfile
      system("bundle add terminalwire")

      # Run the terminalwire install generator
      system("bin/rails generate terminalwire:install hello")

      # Boot the Puma server in the background
      @pid = spawn("bin/rails server -b 0.0.0.0 -p 3000")

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

    FileUtils.remove_entry(@test_app_path) if @test_app_path
  end

  it "runs Terminalwire client against server" do
    # Run the binary and capture output
    output, status = Open3.capture2e("bin/#{binary_name} hello World")
    expect(output.strip).to eql "Hello World"
    expect(status).to be_success
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
