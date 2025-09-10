# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::Directory do
  let(:integration) { 
    Sync::Integration.new(authority: 'directory-test.example.com') do |sync|
      # Allow all directory paths for testing
      sync.policy.paths.permit("**/*", mode: 0o777)
    end
  }
  let(:server_directory) { described_class.new("directory", integration.server_adapter) }
  let(:test_dir) { Dir.mktmpdir('server_resource_test') }

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

  describe 'unauthorized access' do
    let(:restricted_integration) { 
      Sync::Integration.new(authority: 'restricted-directory.example.com') do |sync|
        sync.policy.paths.permit("/tmp/allowed/**", mode: 0o755)
      end
    }
    let(:restricted_directory) { described_class.new("directory", restricted_integration.server_adapter) }

    it 'denies listing unauthorized directories' do
      expect {
        restricted_directory.list("/etc/*")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies creating directories in unauthorized paths' do
      expect {
        restricted_directory.create("/etc/malicious_dir")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies checking existence of unauthorized directories' do
      expect {
        restricted_directory.exist?("/etc")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies deleting unauthorized directories' do
      expect {
        restricted_directory.delete("/etc")
      }.to raise_error(Terminalwire::Error, /denied/)
    end
  end
end