# frozen_string_literal: true

require 'bundler/setup'
require 'terminalwire/server'
require 'terminalwire/client'
require 'tempfile'
require 'stringio'
require_relative '../support/sync_adapter'

RSpec.describe 'Server Resources Integration' do
  let(:sync_adapter) { SyncAdapter.new }
  let(:entitlement) { create_full_entitlement }
  
  before do
    setup_client_resources
  end
  
  def create_full_entitlement
    # Create entitlement that allows everything for testing
    Terminalwire::Client::Entitlement::Policy.resolve(authority: 'test.example.com').tap do |policy|
      # Allow all paths
      policy.paths.permit("**/*", mode: 0o777)
      
      # Allow all environment variables
      policy.environment_variables.permit("TEST_VAR")
      policy.environment_variables.permit("DEFINITELY_NONEXISTENT_VAR_12345")
      policy.environment_variables.permit("HOME")
      policy.environment_variables.permit("USER")
      policy.environment_variables.permit("PATH")
      
      # Allow all URL schemes
      policy.schemes.permit("https")
      policy.schemes.permit("http")
      policy.schemes.permit("ftp")
    end
  end
  
  def setup_client_resources
    client_handler = Terminalwire::Client::Resource::Handler.new do |handler|
      handler << Terminalwire::Client::Resource::File.new("file", sync_adapter.client_adapter, entitlement: entitlement)
      handler << Terminalwire::Client::Resource::STDOUT.new("stdout", sync_adapter.client_adapter, entitlement: entitlement)
      handler << Terminalwire::Client::Resource::STDERR.new("stderr", sync_adapter.client_adapter, entitlement: entitlement)
      handler << Terminalwire::Client::Resource::STDIN.new("stdin", sync_adapter.client_adapter, entitlement: entitlement)
      handler << Terminalwire::Client::Resource::Directory.new("directory", sync_adapter.client_adapter, entitlement: entitlement)
      handler << Terminalwire::Client::Resource::EnvironmentVariable.new("environment_variable", sync_adapter.client_adapter, entitlement: entitlement)
      handler << Terminalwire::Client::Resource::Browser.new("browser", sync_adapter.client_adapter, entitlement: entitlement)
    end
    
    sync_adapter.connect_client(client_handler)
  end

  describe Terminalwire::Server::Resource::File do
    let(:server_file) { described_class.new("file", sync_adapter) }
    let(:test_file) { Tempfile.new('server_resource_test') }
    let(:test_path) { test_file.path }

    after do
      test_file.close
      test_file.unlink if File.exist?(test_file.path)
    end

    describe '#read' do
      it 'reads file content through client' do
        File.write(test_path, "test content")
        
        result = server_file.read(test_path)
        
        expect(result).to eq("test content")
      end
      
      it 'raises error for non-existent file' do
        expect {
          server_file.read("/nonexistent/file.txt")
        }.to raise_error
      end
    end

    describe '#write' do
      it 'writes content to file through client' do
        server_file.write(test_path, "new content")
        
        expect(File.read(test_path)).to eq("new content")
      end
    end

    describe '#append' do
      it 'appends content to existing file' do
        File.write(test_path, "initial")
        
        server_file.append(test_path, " appended")
        
        expect(File.read(test_path)).to eq("initial appended")
      end
    end

    describe '#exist?' do
      it 'returns true for existing file' do
        File.write(test_path, "exists")
        
        result = server_file.exist?(test_path)
        
        expect(result).to be true
      end

      it 'returns false for non-existing file' do
        result = server_file.exist?("/definitely/nonexistent.txt")
        
        expect(result).to be false
      end
    end

    describe '#delete' do
      it 'deletes file through client' do
        File.write(test_path, "to delete")
        
        server_file.delete(test_path)
        
        expect(File.exist?(test_path)).to be false
      end
    end

    describe '#change_mode' do
      it 'changes file permissions through client' do
        File.write(test_path, "test")
        original_mode = File.stat(test_path).mode
        
        server_file.change_mode(test_path, 0755)
        
        new_mode = File.stat(test_path).mode
        expect(new_mode).not_to eq(original_mode)
      end
    end
  end

  describe Terminalwire::Server::Resource::STDOUT do
    let(:server_stdout) { described_class.new("stdout", sync_adapter) }

    describe '#print' do
      it 'prints to stdout through client' do
        expect { server_stdout.print("Hello from server") }.not_to raise_error
      end
    end

    describe '#puts' do
      it 'prints line to stdout through client' do
        expect { server_stdout.puts("Hello line") }.not_to raise_error
      end
    end
  end

  describe Terminalwire::Server::Resource::STDERR do
    let(:server_stderr) { described_class.new("stderr", sync_adapter) }

    describe '#print' do
      it 'prints to stderr through client' do
        expect { server_stderr.print("Error message") }.not_to raise_error
      end
    end

    describe '#puts' do
      it 'prints line to stderr through client' do
        expect { server_stderr.puts("Error line") }.not_to raise_error
      end
    end
  end

  describe Terminalwire::Server::Resource::STDIN do
    let(:server_stdin) { described_class.new("stdin", sync_adapter) }

    describe '#gets' do
      it 'reads line from stdin through client' do
        allow($stdin).to receive(:gets).and_return("test input\n")
        
        result = server_stdin.gets
        
        expect(result).to eq("test input\n")
      end
    end

    describe '#getpass' do
      it 'reads password from stdin through client' do
        allow($stdin).to receive(:getpass).and_return("secret123")
        
        result = server_stdin.getpass
        
        expect(result).to eq("secret123")
      end
    end
  end

  describe Terminalwire::Server::Resource::Directory do
    let(:server_directory) { described_class.new("directory", sync_adapter) }
    let(:test_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(test_dir) if Dir.exist?(test_dir)
    end

    describe '#create' do
      it 'creates directory through client' do
        new_dir = File.join(test_dir, "new_directory")
        
        server_directory.create(new_dir)
        
        expect(Dir.exist?(new_dir)).to be true
      end
    end

    describe '#exist?' do
      it 'returns true for existing directory' do
        result = server_directory.exist?(test_dir)
        
        expect(result).to be true
      end

      it 'returns false for non-existing directory' do
        result = server_directory.exist?("/nonexistent/directory")
        
        expect(result).to be false
      end
    end

    describe '#list' do
      it 'lists directory contents through client' do
        File.write(File.join(test_dir, "file1.txt"), "content1")
        File.write(File.join(test_dir, "file2.txt"), "content2")
        
        result = server_directory.list(File.join(test_dir, "*"))
        
        expect(result).to be_an(Array)
        expect(result.length).to be >= 2
      end
    end

    describe '#delete' do
      it 'deletes empty directory through client' do
        test_subdir = File.join(test_dir, "to_delete")
        Dir.mkdir(test_subdir)
        
        server_directory.delete(test_subdir)
        
        expect(Dir.exist?(test_subdir)).to be false
      end
    end
  end

  describe Terminalwire::Server::Resource::EnvironmentVariable do
    let(:server_env) { described_class.new("environment_variable", sync_adapter) }

    describe '#read' do
      it 'reads existing environment variable through client' do
        ENV['TEST_VAR'] = 'test_value'
        
        result = server_env.read('TEST_VAR')
        
        expect(result).to eq('test_value')
      end

      it 'returns nil for non-existent variable' do
        result = server_env.read('DEFINITELY_NONEXISTENT_VAR_12345')
        
        expect(result).to be_nil
      end
    end
  end

  describe Terminalwire::Server::Resource::Browser do
    let(:server_browser) { described_class.new("browser", sync_adapter) }

    before do
      allow(Launchy).to receive(:open)
    end

    describe '#launch' do
      it 'launches URL through client' do
        expect { server_browser.launch('https://example.com') }.not_to raise_error
        expect(Launchy).to have_received(:open).with(URI('https://example.com'))
      end
    end
  end
end