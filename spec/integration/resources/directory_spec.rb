# frozen_string_literal: true

require 'bundler/setup'
require 'terminalwire/server'
require 'terminalwire/client'
require_relative '../../support/sync_adapter'
require 'fileutils'

RSpec.describe Terminalwire::Server::Resource::Directory do
  let(:sync_adapter) { SyncAdapter.new }
  let(:server_directory) { described_class.new("directory", sync_adapter) }
  let(:test_dir) { Dir.mktmpdir }

  before do
    # Create policy that allows directory operations
    entitlement = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'directory-test.example.com').tap do |policy|
      policy.paths.permit("**/*", mode: 0o777)
    end

    # Setup client resources
    client_handler = Terminalwire::Client::Resource::Handler.new do |handler|
      handler << Terminalwire::Client::Resource::Directory.new("directory", sync_adapter.client_adapter, entitlement: entitlement)
    end
    
    sync_adapter.connect_client(client_handler)
  end

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