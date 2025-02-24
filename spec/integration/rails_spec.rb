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

  def console(&)
    Pity::REPL.new("docker exec -it #{@docker_id} bash", &)
  end

  it "runs Terminalwire client against server" do
    console do
      it.puts "#{BINARY_NAME} hello World"
      expect(it.expect("Hello World")).to include("Hello World")
    end
  end

  it "logs in successfully" do
    shell = "docker exec -it #{@docker_id} bash"
    console do
      it.puts "#{BINARY_NAME} login"
      it.expect "Email: "
      it.puts "brad@example.com"
      it.expect "Password: "
      it.puts "password123"
      expect(it.expect("Successfully logged in as brad@example.com")).to include("Successfully logged in as brad@example.com.")
    end
  end

  it "runs unknown commands" do
    console do |repl|
      repl.puts "#{BINARY_NAME} nothingburger"
      repl.gets.tap do |buffer|
        expect(buffer).to include("Could not find command \"nothingburger\".")
        expect(buffer).to_not include("Thor::UndefinedCommandError")
      end
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
