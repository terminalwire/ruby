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

  PORT = 3000

  before(:all) do
    `docker build -t terminalwire-rails-server -f containers/rails/Dockerfile .`
    @docker_id = `docker run -d terminalwire-rails-server`.chomp
    wait_for_server("0.0.0.0", PORT)

    @path = Pathname.new(Dir.mktmpdir)
    @bin_path = @path.join("bin").tap(&:mkdir)

    @bin_path.join("hello").tap do |file|
      file.write <<~BASH
        #!/usr/bin/env terminalwire-exec
        url: "http://localhost:#{PORT}/terminal"
      BASH
      file.chmod(0o755)
    end

    ENV["PATH"] = "#{@bin_path.to_s}:#{ENV["PATH"]}"

    Dir.chdir(@path) do
      Bundler.with_unbundled_env do
        `bundle install --path #{@path} --binstubs=#{@bin_path} --quiet`
      end
    end
  end

  after(:all) do
    `docker stop #{@docker_id}` if @docker_id
  end

  it "runs Terminalwire client against server" do
    # Run the binary and capture output
    output, status = Open3.capture2e("#{binary_name} hello World")
    expect(output.strip).to eql "Hello World"
    expect(status).to be_success
  end

  it "logs in successfully" do
    PTY.spawn("#{binary_name} login") do |stdout, stdin, pid|
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

  def wait_for_server(host, port, timeout: 5)
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
