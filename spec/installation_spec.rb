require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"
require "socket"

RSpec.describe "Terminalwire Install", type: :system do
  let(:binary_name) { "hello" }
  let(:terminalwire_gem_path) { File.expand_path('../../../', __FILE__) }

  around do |example|
    Dir.mktmpdir do |test_app_path|
      Dir.chdir(test_app_path) do
        Bundler.with_unbundled_env do
          # Create a bare Rails app
          system("rails new . --minimal --skip-bundle")

          # Add terminalwire gem to Gemfile
          gemfile_path = File.join(test_app_path, "Gemfile")
          File.open(gemfile_path, "a") do |file|
            file.puts "\ngem 'terminalwire', path: '#{terminalwire_gem_path}'"
          end

          # Bundle install
          system("bundle install")

          # Run the terminalwire install generator
          system("bin/rails generate terminalwire:install #{binary_name}")

          # Boot the Puma server in the background
          pid = spawn("bin/rails server -b 0.0.0.0 -p 3000")

          begin
            # Poll until the server is ready
            wait_for_server("0.0.0.0", 3000)

            # Run the test
            example.run
          ensure
            # Kill the server after the test
            Process.kill("TERM", pid)
            Process.wait(pid)
          end
        end
      end
    end
  end

  it "runs Terminalwire client against server" do
    # Run the binary and capture output
    output, status = Open3.capture2e("bin/#{binary_name} hello World")
    expect(status.success?).to be(true)
    expect(output.strip).to eql "Hello World"
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
