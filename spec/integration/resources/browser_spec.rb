# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::Browser do
  let(:integration) { 
    Sync::Integration.new(authority: 'browser-test.example.com') do |sync|
      # Allow HTTP and HTTPS schemes for testing
      sync.policy.schemes.permit("http")
      sync.policy.schemes.permit("https")
      # Add FTP for testing purposes
      sync.policy.schemes.permit("ftp")
    end
  }
  let(:server_browser) { described_class.new("browser", integration.server_adapter) }

  before do
    allow(Launchy).to receive(:open)
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
