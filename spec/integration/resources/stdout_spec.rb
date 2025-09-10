# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDOUT do
  let(:sync_adapter) { SyncAdapter.new }
  let(:server_stdout) { described_class.new("stdout", sync_adapter) }

  before do
    # Create policy that allows stdout operations (no special permissions needed)
    entitlement = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'stdout-test.example.com')

    # Setup client resources
    client_handler = Terminalwire::Client::Resource::Handler.new(adapter: sync_adapter.client_adapter, entitlement: entitlement) do |handler|
      handler << Terminalwire::Client::Resource::STDOUT
    end
    
    sync_adapter.connect_client(client_handler)
  end

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

  describe '#flush' do
    it 'does nothing but succeeds' do
      expect { server_stdout.flush }.not_to raise_error
    end
  end
end