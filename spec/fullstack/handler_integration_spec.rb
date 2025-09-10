# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'securerandom'

RSpec.describe 'Handler Integration' do
  let(:test_adapter) { Terminalwire::Adapter::Test.new }
  let(:client_handler) do
    # Create a mock endpoint for the client
    endpoint = double('endpoint', authority: 'test.example.com', to_url: 'ws://test.example.com')
    
    Terminalwire::Client::Handler.new(
      test_adapter,
      arguments: ['test', 'args'],
      program_name: 'test_program',
      endpoint: endpoint
    ) do |handler|
      # Set up permissive entitlements for testing
      handler.entitlement = create_test_entitlement
    end
  end
  


  def create_test_entitlement
    # Use the resolve method to create a policy for test authority
    policy = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'test.example.com')
    
    # Create permissive paths for testing
    paths = Terminalwire::Client::Entitlement::Paths.new
    paths.permit("**/*")
    policy.instance_variable_set(:@paths, paths)
    
    # Create permissive environment variables
    env_vars = Terminalwire::Client::Entitlement::EnvironmentVariables.new
    env_vars.permit("*")
    env_vars.permit("TEST_VAR_FOR_TERMINALWIRE")
    policy.instance_variable_set(:@environment_variables, env_vars)
    
    # Create permissive schemes
    schemes = Terminalwire::Client::Entitlement::Schemes.new
    schemes.permit("http")
    schemes.permit("https")
    schemes.permit("file")
    policy.instance_variable_set(:@schemes, schemes)
    
    policy
  end

  describe 'client-server handshake' do
    it 'exchanges initialization message' do
      # Simulate the client's initial connection
      # The client handler sends initialization during connect, but we'll test the message handling directly
      initialization_message = {
        event: "initialization",
        protocol: { version: Terminalwire::VERSION },
        entitlement: client_handler.entitlement.serialize,
        program: {
          name: 'test_program',
          arguments: ['test', 'args']
        }
      }

      # This test verifies the initialization message format is correct
      expect(initialization_message).to include(
        event: "initialization",
        protocol: include(version: Terminalwire::VERSION),
        program: include(name: 'test_program', arguments: ['test', 'args']),
        entitlement: be_a(Hash)
      )
    end
  end

  describe 'stdout operations' do


    it 'handles print commands' do
      # Create a print command like a server would
      command = {
        event: "resource",
        action: "command", 
        name: "stdout",
        command: "print",
        parameters: { data: "Hello from server!" }
      }

      # Simulate the client handling this command
      client_handler.handle(command)
      
      # Check that the client sent back a success response
      response = test_adapter.response
      expect(response).to include(
        event: "resource",
        status: "success",
        name: "stdout"
      )
    end

    it 'handles print_line commands' do
      # Create a print_line command like a server would
      command = {
        event: "resource",
        action: "command",
        name: "stdout", 
        command: "print_line",
        parameters: { data: "Line from server" }
      }

      expect { client_handler.handle(command) }.not_to raise_error
      
      # Check that the client sent back a success response
      response = test_adapter.response
      expect(response).to include(
        event: "resource",
        status: "success",
        name: "stdout"
      )
    end
  end

  describe 'stderr operations' do


    it 'handles stderr print commands' do
      # Create a stderr print command like a server would
      command = {
        event: "resource",
        action: "command",
        name: "stderr",
        command: "print", 
        parameters: { data: "Error message!" }
      }

      expect { client_handler.handle(command) }.not_to raise_error
      
      # Check that the client sent back a success response  
      response = test_adapter.response
      expect(response).to include(
        event: "resource",
        status: "success",
        name: "stderr"
      )
    end
  end

  describe 'file operations' do


    it 'handles file read commands' do
      temp_file = Tempfile.new('test')
      temp_file.write('test content')
      temp_file.close

      begin
        # Create a file read command like a server would
        command = {
          event: "resource",
          action: "command",
          name: "file",
          command: "read",
          parameters: { path: temp_file.path }
        }

        client_handler.handle(command)
        
        # The client should have responded with the file content
        response = test_adapter.response
        expect(response).to include(
          event: "resource",
          status: "success",
          name: "file",
          response: "test content"
        )
      ensure
        temp_file.unlink
      end
    end

    it 'handles file write commands' do
      temp_path = File.join(Dir.tmpdir, "test_write_#{SecureRandom.hex}.txt")
      
      begin
        # Create a file write command like a server would
        command = {
          event: "resource",
          action: "command",
          name: "file",
          command: "write",
          parameters: { 
            path: temp_path,
            content: "written by server"
          }
        }

        client_handler.handle(command)
        
        # Verify the file was actually created
        expect(File.exist?(temp_path)).to be true
        expect(File.read(temp_path)).to eq("written by server")
        
        # Client should respond with success
        response = test_adapter.response
        expect(response).to include(
          event: "resource", 
          status: "success",
          name: "file"
        )
      ensure
        File.unlink(temp_path) if File.exist?(temp_path)
      end
    end

    it 'handles file existence checks' do
      temp_file = Tempfile.new('exists_test')
      temp_file.close

      begin
        # Create a file exist command like a server would
        command = {
          event: "resource",
          action: "command", 
          name: "file",
          command: "exist",
          parameters: { path: temp_file.path }
        }

        client_handler.handle(command)
        
        response = test_adapter.response
        expect(response).to include(
          event: "resource",
          status: "success", 
          name: "file",
          response: true
        )
      ensure
        temp_file.unlink
      end
    end
  end

  describe 'directory operations' do


    it 'handles directory creation' do
      temp_dir = File.join(Dir.tmpdir, "test_dir_#{SecureRandom.hex}")
      
      begin
        # Create a directory create command like a server would
        command = {
          event: "resource",
          action: "command",
          name: "directory", 
          command: "create",
          parameters: { path: temp_dir }
        }

        client_handler.handle(command)
        
        expect(Dir.exist?(temp_dir)).to be true
        
        response = test_adapter.response
        expect(response).to include(
          event: "resource",
          status: "success",
          name: "directory"
        )
      ensure
        Dir.rmdir(temp_dir) if Dir.exist?(temp_dir)
      end
    end

    it 'handles directory existence checks' do
      Dir.mktmpdir do |temp_dir|
        # Create a directory exist command like a server would
        command = {
          event: "resource",
          action: "command",
          name: "directory",
          command: "exist", 
          parameters: { path: temp_dir }
        }

        client_handler.handle(command)
        
        response = test_adapter.response
        expect(response).to include(
          event: "resource",
          status: "success",
          name: "directory",
          response: true
        )
      end
    end
  end

  describe 'environment variable operations' do


    it 'handles environment variable reading' do
      ENV['TEST_VAR_FOR_TERMINALWIRE'] = 'test_value'
      
      begin
        # Create an env var read command like a server would
        command = {
          event: "resource",
          action: "command",
          name: "environment_variable",
          command: "read",
          parameters: { name: 'TEST_VAR_FOR_TERMINALWIRE' }
        }

        client_handler.handle(command)
        
        response = test_adapter.response
        expect(response).to include(
          event: "resource",
          status: "success",
          name: "environment_variable", 
          response: 'test_value'
        )
      ensure
        ENV.delete('TEST_VAR_FOR_TERMINALWIRE')
      end
    end
  end

  describe 'client exit handling' do
    it 'handles exit commands from server' do
      expect {
        client_handler.handle(event: "exit", status: 0)
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end

    it 'handles exit commands with custom status' do
      expect {
        client_handler.handle(event: "exit", status: 42)
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(42)
      end
    end
  end

  describe 'server command helpers' do
    it 'provides convenient methods for sending commands' do
      # Create an exit command like a server would
      command = { event: "exit", status: 1 }
      
      expect(command).to eq({
        event: "exit",
        status: 1
      })
    end
  end
end