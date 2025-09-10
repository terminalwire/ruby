# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::File do
  let(:integration) { 
    Sync::Integration.new(authority: 'file-test.example.com') do |sync|
      sync.policy.paths.permit("**/*", mode: 0o777)
    end
  }
  let(:server_file) { described_class.new("file", integration.server_adapter) }
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
      }.to raise_error(Errno::ENOENT, /No such file or directory/)
    end

    it 'raises error for unauthorized file access' do
      integration_with_no_perms = Sync::Integration.new(authority: 'file-test-no-perms.example.com')
      restricted_file = Terminalwire::Server::Resource::File.new("file", integration_with_no_perms.server_adapter)
      
      expect {
        restricted_file.read(test_path)
      }.to raise_error(/denied/)
    end
  end

  describe '#write' do
    it 'writes content to file through client' do
      server_file.write(test_path, "new content")
      
      expect(File.read(test_path)).to eq("new content")
    end

    it 'overwrites existing file content' do
      File.write(test_path, "original content")
      
      server_file.write(test_path, "replacement content")
      
      expect(File.read(test_path)).to eq("replacement content")
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
      
      server_file.change_mode(test_path, 0644)
      
      mode = File.stat(test_path).mode & 0777
      expect(mode).to eq(0644)
    end
  end

  describe 'unauthorized access' do
    let(:restricted_integration) { 
      Sync::Integration.new(authority: 'restricted-file.example.com') do |sync|
        sync.policy.paths.permit("/tmp/allowed/**", mode: 0o644)
      end
    }
    let(:restricted_file) { described_class.new("file", restricted_integration.server_adapter) }

    it 'denies reading unauthorized paths' do
      expect {
        restricted_file.read("/etc/passwd")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies writing to unauthorized paths' do
      expect {
        restricted_file.write("/etc/malicious", "bad content")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies deleting unauthorized files' do
      expect {
        restricted_file.delete("/etc/passwd")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies changing permissions on unauthorized files' do
      expect {
        restricted_file.change_mode("/etc/passwd", 0777)
      }.to raise_error(Terminalwire::Error, /denied/)
    end
  end
end