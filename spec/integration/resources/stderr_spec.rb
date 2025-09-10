# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDERR do
  let(:sync_adapter) { SyncAdapter.new }
  let(:server_stderr) { described_class.new("stderr", sync_adapter) }

  before do
    # Create policy that allows stderr operations (no special permissions needed)
    entitlement = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'stderr-test.example.com')

    # Setup client resources
    client_handler = Terminalwire::Client::Resource::Handler.new(adapter: sync_adapter.client_adapter, entitlement: entitlement) do |handler|
      handler << Terminalwire::Client::Resource::STDERR
    end
    
    sync_adapter.connect_client(client_handler)
  end

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

  describe '#flush' do
    it 'does nothing but succeeds' do
      expect { server_stderr.flush }.not_to raise_error
    end
  end
end