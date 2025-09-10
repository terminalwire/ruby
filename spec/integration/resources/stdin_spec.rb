# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDIN do
  let(:integration) { 
    Sync::Integration.new(authority: 'stdin-test.example.com') 
  }
  let(:server_stdin) { described_class.new("stdin", integration.server_adapter) }

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