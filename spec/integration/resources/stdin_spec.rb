# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDIN do
  let(:sync_adapter) { SyncAdapter.new }
  let(:server_stdin) { described_class.new("stdin", sync_adapter) }

  before do
    # Create policy that allows stdin operations (no special permissions needed)
    entitlement = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'stdin-test.example.com')

    # Setup client resources
    client_handler = Terminalwire::Client::Resource::Handler.new(adapter: sync_adapter.client_adapter, entitlement: entitlement) do |handler|
      handler << Terminalwire::Client::Resource::STDIN
    end
    
    sync_adapter.connect_client(client_handler)
  end

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