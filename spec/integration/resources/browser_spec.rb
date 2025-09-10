# frozen_string_literal: true

require 'bundler/setup'
require 'terminalwire/server'
require 'terminalwire/client'
require_relative '../../support/sync_adapter'

RSpec.describe Terminalwire::Server::Resource::Browser do
  let(:sync_adapter) { SyncAdapter.new }
  let(:server_browser) { described_class.new("browser", sync_adapter) }

  before do
    allow(Launchy).to receive(:open)
    
    # Create policy that allows specific URL schemes
    entitlement = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'browser-test.example.com').tap do |policy|
      policy.schemes.permit("https")
      policy.schemes.permit("http") 
      policy.schemes.permit("ftp")
    end

    # Setup client resources
    client_handler = Terminalwire::Client::Resource::Handler.new do |handler|
      handler << Terminalwire::Client::Resource::Browser.new("browser", sync_adapter.client_adapter, entitlement: entitlement)
    end
    
    sync_adapter.connect_client(client_handler)
  end

  describe '#launch' do
    it 'launches HTTPS URLs' do
      expect { server_browser.launch('https://example.com') }.not_to raise_error
      expect(Launchy).to have_received(:open).with(URI('https://example.com'))
    end

    it 'launches HTTP URLs' do
      expect { server_browser.launch('http://example.com') }.not_to raise_error
      expect(Launchy).to have_received(:open).with(URI('http://example.com'))
    end

    it 'launches FTP URLs' do
      expect { server_browser.launch('ftp://example.com') }.not_to raise_error
      expect(Launchy).to have_received(:open).with(URI('ftp://example.com'))
    end
  end
end