# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'securerandom'
require 'stringio'

# Test adapter that simulates the server-client request-response cycle
class ServerClientTestAdapter
  def initialize(client_handler)
    @client_handler = client_handler
    @commands = []
    @last_response = nil
  end
  
  def write(**command)
    @commands << command
    
    # Simulate client handling the command
    @client_handler.handle(command)
    
    # Get and store the client's response
    @last_response = @client_handler.adapter.response
  end
  
  def read
    # Return the stored response (server resources expect this)
    @last_response
  end
  
  def close
    # No-op
  end
end

RSpec.describe 'Server Resources Integration' do
  let(:test_adapter) { Terminalwire::Adapter::Test.new }
  let(:client_handler) do
    endpoint = double('endpoint', authority: 'test.example.com', to_url: 'ws://test.example.com')
    
    Terminalwire::Client::Handler.new(
      test_adapter,
      arguments: ['test', 'args'],
      program_name: 'test_program',
      endpoint: endpoint
    ) do |handler|
      handler.entitlement = create_test_entitlement
    end
  end

  def create_test_entitlement
    policy = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'test.example.com')
    
    # Allow all file operations with any mode
    paths = Terminalwire::Client::Entitlement::Paths.new
    paths.permit("**/*", mode: 0o777)
    policy.instance_variable_set(:@paths, paths)
    
    # Allow all environment variables
    env_vars = Terminalwire::Client::Entitlement::EnvironmentVariables.new
    env_vars.permit("*")
    env_vars.permit("TEST_SERVER_RESOURCE_VAR") 
    env_vars.permit("NONEXISTENT_VAR_12345")
    env_vars.permit("TERMINALWIRE_HOME")
    env_vars.permit("TEST_NONEXISTENT_VAR")
    env_vars.permit("RESPONSE_TEST_VAR")
    policy.instance_variable_set(:@environment_variables, env_vars)
    
    # Allow all URL schemes
    schemes = Terminalwire::Client::Entitlement::Schemes.new
    schemes.permit("http")
    schemes.permit("https")
    schemes.permit("file")
    schemes.permit("ftp")
    policy.instance_variable_set(:@schemes, schemes)
    
    policy
  end

  # Helper to test server resource methods by creating a connected pair
  def test_server_resource(resource_class, method_name, *args, **kwargs)
    # Create adapter that handles the request-response cycle
    server_client_adapter = ServerClientTestAdapter.new(client_handler)
    
    # Create server resource that will communicate with client
    # Map resource class names to the correct client resource names
    resource_name = case resource_class.name.split('::').last
                   when 'STDOUT' then 'stdout'
                   when 'STDERR' then 'stderr'
                   when 'STDIN' then 'stdin'
                   when 'File' then 'file'
                   when 'Directory' then 'directory'
                   when 'EnvironmentVariable' then 'environment_variable'
                   when 'Browser' then 'browser'
                   else
                     resource_class.name.split('::').last.downcase
                   end
    server_resource = resource_class.new(resource_name, server_client_adapter)
    
    # Execute the server resource method
    # This will send command to client and wait for response
    result = server_resource.public_send(method_name, *args, **kwargs)
    
    return result
  end

  describe 'Terminalwire::Server::Resource::STDOUT' do
    it 'sends print command and client outputs to stdout' do
      captured_output = StringIO.new
      original_stdout = $stdout
      $stdout = captured_output

      begin
        result = test_server_resource(Terminalwire::Server::Resource::STDOUT, :print, "Hello from server")
        
        expect(captured_output.string).to eq("Hello from server")
        expect(result).to be_nil # STDOUT operations return nil on success
      ensure
        $stdout = original_stdout
      end
    end

    it 'sends print_line command and client outputs with newline' do
      captured_output = StringIO.new
      original_stdout = $stdout
      $stdout = captured_output

      begin
        result = test_server_resource(Terminalwire::Server::Resource::STDOUT, :puts, "Hello line")
        
        expect(captured_output.string).to eq("Hello line\n")
        expect(result).to be_nil # STDOUT operations return nil on success
      ensure
        $stdout = original_stdout
      end
    end
  end

  describe 'Terminalwire::Server::Resource::STDERR' do
    it 'sends print command and client outputs to stderr' do
      captured_output = StringIO.new
      original_stderr = $stderr
      $stderr = captured_output

      begin
        result = test_server_resource(Terminalwire::Server::Resource::STDERR, :print, "Error message")
        
        expect(captured_output.string).to eq("Error message")
        expect(result).to be_nil # STDERR operations return nil on success
      ensure
        $stderr = original_stderr
      end
    end

    it 'sends print_line command and client outputs to stderr with newline' do
      captured_output = StringIO.new
      original_stderr = $stderr
      $stderr = captured_output

      begin
        result = test_server_resource(Terminalwire::Server::Resource::STDERR, :puts, "Error line")
        
        expect(captured_output.string).to eq("Error line\n")
        expect(result).to be_nil # STDERR operations return nil on success
      ensure
        $stderr = original_stderr
      end
    end
  end

  describe 'Terminalwire::Server::Resource::STDIN' do
    it 'sends read_line command and client reads from stdin' do
      original_stdin = $stdin
      $stdin = StringIO.new("user input line\n")

      begin
        result = test_server_resource(Terminalwire::Server::Resource::STDIN, :gets)
        expect(result).to eq("user input line\n")
      ensure
        $stdin = original_stdin
      end
    end

    it 'sends read_password command and client reads password' do
      original_stdin = $stdin
      mock_stdin = double('stdin')
      allow(mock_stdin).to receive(:getpass).and_return("secret123")
      $stdin = mock_stdin

      begin
        result = test_server_resource(Terminalwire::Server::Resource::STDIN, :getpass)
        expect(result).to eq("secret123")
      ensure
        $stdin = original_stdin
      end
    end
  end

  describe 'Terminalwire::Server::Resource::File' do
    it 'sends read command and client reads file content' do
      temp_file = Tempfile.new('server_resource_test')
      temp_file.write('test file content from server')
      temp_file.close

      begin
        result = test_server_resource(Terminalwire::Server::Resource::File, :read, temp_file.path)
        expect(result).to eq("test file content from server")
      ensure
        temp_file.unlink
      end
    end

    it 'sends write command and client creates file' do
      temp_path = File.join(Dir.tmpdir, "server_test_#{SecureRandom.hex}.txt")
      
      begin
        result = test_server_resource(Terminalwire::Server::Resource::File, :write, temp_path, "written by server resource")
        
        expect(File.exist?(temp_path)).to be true
        expect(File.read(temp_path)).to eq("written by server resource")
        expect(result).to be_a(Integer) # write returns bytes written
      ensure
        File.unlink(temp_path) if File.exist?(temp_path)
      end
    end

    it 'sends append command and client appends to file' do
      temp_file = Tempfile.new('server_append_test')
      temp_file.write('initial content')
      temp_file.close

      begin
        result = test_server_resource(Terminalwire::Server::Resource::File, :append, temp_file.path, " appended by server")
        
        expect(File.read(temp_file.path)).to eq("initial content appended by server")
        expect(result).to be_a(Integer) # append returns bytes written
      ensure
        temp_file.unlink
      end
    end

    it 'sends exist command for existing file and client returns true' do
      temp_file = Tempfile.new('server_exist_test')
      temp_file.close

      begin
        result = test_server_resource(Terminalwire::Server::Resource::File, :exist?, temp_file.path)
        expect(result).to be true
      ensure
        temp_file.unlink
      end
    end

    it 'sends exist command for non-existing file and client returns false' do
      nonexistent_path = "/tmp/nonexistent_#{SecureRandom.hex}.txt"
      
      result = test_server_resource(Terminalwire::Server::Resource::File, :exist?, nonexistent_path)
      expect(result).to be false
    end

    it 'sends delete command and client deletes file' do
      temp_file = Tempfile.new('server_delete_test')
      temp_path = temp_file.path
      temp_file.close

      result = test_server_resource(Terminalwire::Server::Resource::File, :delete, temp_path)
      
      expect(File.exist?(temp_path)).to be false
      expect(result).to eq(1) # delete returns number of files deleted
    end

    it 'sends change_mode command and client changes file permissions' do
      temp_file = Tempfile.new('server_chmod_test')
      temp_file.close

      begin
        result = test_server_resource(Terminalwire::Server::Resource::File, :change_mode, temp_file.path, 0o444)
        
        expect(File.stat(temp_file.path).mode & 0o777).to eq(0o444)
        expect(result).to eq(1) # chmod returns number of files changed
      ensure
        # Restore permissions for cleanup
        File.chmod(0o644, temp_file.path) rescue nil
        temp_file.unlink
      end
    end

    it 'handles file not found error gracefully' do
      nonexistent_path = "/tmp/definitely_nonexistent_#{SecureRandom.hex}.txt"
      
      # Client will raise Errno::ENOENT for file not found, which server resource wraps
      expect {
        test_server_resource(Terminalwire::Server::Resource::File, :read, nonexistent_path)
      }.to raise_error(Errno::ENOENT)
    end
  end

  describe 'Terminalwire::Server::Resource::Directory' do
    it 'sends create command and client creates directory' do
      temp_dir = File.join(Dir.tmpdir, "server_dir_test_#{SecureRandom.hex}")
      
      begin
        result = test_server_resource(Terminalwire::Server::Resource::Directory, :create, temp_dir)
        
        expect(Dir.exist?(temp_dir)).to be true
        expect(result).to be_a(Array) # create returns array of created directories
      ensure
        Dir.rmdir(temp_dir) if Dir.exist?(temp_dir)
      end
    end

    it 'sends exist command for existing directory and client returns true' do
      Dir.mktmpdir do |temp_dir|
        result = test_server_resource(Terminalwire::Server::Resource::Directory, :exist?, temp_dir)
        expect(result).to be true
      end
    end

    it 'sends exist command for non-existing directory and client returns false' do
      nonexistent_dir = "/tmp/nonexistent_dir_#{SecureRandom.hex}"
      
      result = test_server_resource(Terminalwire::Server::Resource::Directory, :exist?, nonexistent_dir)
      expect(result).to be false
    end

    it 'sends list command and client returns directory contents' do
      Dir.mktmpdir do |temp_dir|
        # Create test files
        File.write(File.join(temp_dir, "file1.txt"), "content1")
        File.write(File.join(temp_dir, "file2.txt"), "content2")
        
        result = test_server_resource(Terminalwire::Server::Resource::Directory, :list, "#{temp_dir}/*")
        
        expect(result).to be_a(Array)
        expect(result.size).to eq(2)
        expect(result).to include(File.join(temp_dir, "file1.txt"))
        expect(result).to include(File.join(temp_dir, "file2.txt"))
      end
    end

    it 'sends delete command and client deletes directory' do
      temp_dir = File.join(Dir.tmpdir, "server_dir_delete_#{SecureRandom.hex}")
      Dir.mkdir(temp_dir)
      
      result = test_server_resource(Terminalwire::Server::Resource::Directory, :delete, temp_dir)
      
      expect(Dir.exist?(temp_dir)).to be false
      expect(result).to eq(0) # delete returns 0 on success
    end
  end

  describe 'Terminalwire::Server::Resource::EnvironmentVariable' do
    it 'sends read command and client returns environment variable value' do
      ENV['TEST_SERVER_RESOURCE_VAR'] = 'test_value_from_server'
      
      begin
        result = test_server_resource(Terminalwire::Server::Resource::EnvironmentVariable, :read, "TEST_SERVER_RESOURCE_VAR")
        expect(result).to eq("test_value_from_server")
      ensure
        ENV.delete('TEST_SERVER_RESOURCE_VAR')
      end
    end

    it 'sends read command for non-existent variable and client returns nil' do
      result = test_server_resource(Terminalwire::Server::Resource::EnvironmentVariable, :read, "TEST_NONEXISTENT_VAR")
      expect(result).to be_nil
    end

    context 'with restricted entitlements' do
      let(:restricted_client_handler) do
        endpoint = double('endpoint', authority: 'test.example.com', to_url: 'ws://test.example.com')
        
        Terminalwire::Client::Handler.new(
          test_adapter,
          arguments: ['test', 'args'],
          program_name: 'test_program',
          endpoint: endpoint
        ) do |handler|
          policy = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'test.example.com')
          
          # Only allow specific environment variables
          env_vars = Terminalwire::Client::Entitlement::EnvironmentVariables.new
          env_vars.permit("ALLOWED_VAR")
          policy.instance_variable_set(:@environment_variables, env_vars)
          
          handler.entitlement = policy
        end
      end

      it 'denies access to restricted environment variables' do
        ENV['RESTRICTED_VAR'] = 'secret_value'
        
        begin
          # Use the restricted client handler for this test
          restricted_client_adapter = ServerClientTestAdapter.new(restricted_client_handler)
          server_resource = Terminalwire::Server::Resource::EnvironmentVariable.new("environment_variable", restricted_client_adapter)
          
          expect {
            server_resource.read("RESTRICTED_VAR")
          }.to raise_error(Terminalwire::Error, /failure/)
        ensure
          ENV.delete('RESTRICTED_VAR')
        end
      end
    end
  end

  describe 'Terminalwire::Server::Resource::Browser' do
    before do
      # Mock Launchy globally for all browser tests to prevent actual browser opening
      allow(Launchy).to receive(:open)
    end

    it 'sends launch command and client opens URL' do
      result = test_server_resource(Terminalwire::Server::Resource::Browser, :launch, "https://example.com")
      
      expect(result).to be_nil # launch returns nil
      expect(Launchy).to have_received(:open).with(URI("https://example.com"))
    end

    context 'with restricted entitlements' do
      let(:restricted_client_handler) do
        endpoint = double('endpoint', authority: 'test.example.com', to_url: 'ws://test.example.com')
        
        Terminalwire::Client::Handler.new(
          test_adapter,
          arguments: ['test', 'args'],
          program_name: 'test_program',
          endpoint: endpoint
        ) do |handler|
          policy = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'test.example.com')
          
          # Only allow HTTPS schemes
          schemes = Terminalwire::Client::Entitlement::Schemes.new
          schemes.permit("https")
          policy.instance_variable_set(:@schemes, schemes)
          
          handler.entitlement = policy
        end
      end

      it 'denies access to restricted URL schemes' do
        # Use a restricted adapter for this test
        restricted_client_adapter = ServerClientTestAdapter.new(restricted_client_handler)
        server_resource = Terminalwire::Server::Resource::Browser.new("browser", restricted_client_adapter)
        
        expect {
          server_resource.launch("ftp://evil.com")
        }.to raise_error(Terminalwire::Error, /failure/)
      end
    end
  end

  describe 'Server Resource API compatibility' do
    it 'ensures server resource command format matches what client expects' do
      # This test verifies the command format server resources generate
      # is exactly what the client handler expects
      
      # Test each resource type generates correct command format
      resources_and_commands = [
        ["stdout", "print", { data: "test" }],
        ["stderr", "print_line", { data: "test" }], 
        ["stdin", "read_line", {}],
        ["file", "read", { path: "/test/path" }],
        ["directory", "list", { path: "/test/path" }],
        ["environment_variable", "read", { name: "TEST_VAR" }],
        ["browser", "launch", { url: "https://test.com" }]
      ]
      
      resources_and_commands.each do |name, command, parameters|
        message = {
          event: "resource",
          action: "command",
          name: name,
          command: command, 
          parameters: parameters
        }
        
        # Verify the message format doesn't cause errors in client handler
        expect { client_handler.handle(message) }.not_to raise_error(ArgumentError)
        
        # Clean up any responses
        test_adapter.response
      end
    end

    it 'verifies server resources work with client handlers' do
      # Test that server resources can successfully communicate with client
      
      # Test STDOUT resource
      result = test_server_resource(Terminalwire::Server::Resource::STDOUT, :print, "test")
      expect(result).to be_nil
      
      # Test file existence check
      temp_file = Tempfile.new('response_test')
      temp_file.write('test')
      temp_file.close
      
      begin
        result = test_server_resource(Terminalwire::Server::Resource::File, :exist?, temp_file.path)
        expect(result).to be true
        
        # Test directory existence
        result = test_server_resource(Terminalwire::Server::Resource::Directory, :exist?, Dir.tmpdir)
        expect(result).to be true
        
        # Test environment variable
        ENV['RESPONSE_TEST_VAR'] = 'test'
        result = test_server_resource(Terminalwire::Server::Resource::EnvironmentVariable, :read, "RESPONSE_TEST_VAR")
        expect(result).to eq('test')
        ENV.delete('RESPONSE_TEST_VAR')
      ensure
        temp_file.unlink
      end
    end
  end
end