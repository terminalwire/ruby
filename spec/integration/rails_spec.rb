require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"
require "pathname"
require "pty"
require "io/wait"

RSpec.describe "Terminalwire Install", type: :system do
  DOCKER_IMAGE = "terminalwire-rails-server"
  BINARY_NAME  = "bin/hello"
  PORT         = 3000

  before(:all) do
    build_command = "docker build -t #{DOCKER_IMAGE} -f containers/rails/Dockerfile ."
    system(build_command) or raise "Docker build failed: #{build_command}"

    # Run the container without external port binding and capture the container ID.
    @docker_id = `docker run --rm -d #{DOCKER_IMAGE}`.chomp
    raise "Docker run failed" if @docker_id.empty?

    wait_for_server_in_container(timeout: 15)
  end

  after(:all) do
    system("docker stop #{@docker_id}") if @docker_id
  end

  it "runs Terminalwire client against server" do
    command = "docker exec #{@docker_id} #{BINARY_NAME} hello World"
    output, status = Open3.capture2e(command)
    expect(output.strip).to eql "Hello World"
    expect(status).to be_success
  end

  it "logs in successfully" do
    command = "docker exec -i #{@docker_id} #{BINARY_NAME} login"
    PTY.spawn(command) do |stdout, stdin, pid|
      sleep 0.5
      stdin.puts "brad@example.com"
      sleep 0.5
      stdin.puts "password123"
      output = stdout.read
      expect(output).to include("Successfully logged in as brad@example.com.")
      Process.wait(pid)
      expect($?.success?).to be_truthy
    end
  end

  private

  def wait_for_server_in_container(timeout:)
    start_time = Time.now
    until Time.now - start_time > timeout
      response = `docker exec #{@docker_id} curl -s http://localhost:3000/health`
      return if !response.strip.empty?
      sleep 0.5
    end
    raise "Server did not start within #{timeout} seconds"
  end
end
