# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::Browser do
  let(:integration) { 
    Sync::Integration.new(authority: 'browser-test.example.com') do |sync|
      sync.policy.schemes.permit("http")
      sync.policy.schemes.permit("https")
    end
  }
  let(:server_browser) { described_class.new("browser", integration.server_adapter) }

  before do
    allow(Launchy).to receive(:open)
  end

  describe '#launch' do
    context 'with permitted schemes' do
      it 'opens HTTPS URLs in browser' do
        server_browser.launch('https://example.com')
        expect(Launchy).to have_received(:open).with(URI('https://example.com'))
      end

      it 'opens HTTP URLs in browser' do
        server_browser.launch('http://example.com')
        expect(Launchy).to have_received(:open).with(URI('http://example.com'))
      end

      it 'opens URLs with paths' do
        server_browser.launch('https://example.com/path/to/page')
        expect(Launchy).to have_received(:open).with(URI('https://example.com/path/to/page'))
      end
    end

    context 'with URL parameters' do
      it 'handles URLs with query parameters' do
        server_browser.launch('https://example.com?param=value')
        expect(Launchy).to have_received(:open).with(URI('https://example.com?param=value'))
      end

      it 'handles URLs with fragments' do
        server_browser.launch('https://example.com#section')
        expect(Launchy).to have_received(:open).with(URI('https://example.com#section'))
      end
    end

    context 'with unauthorized schemes' do
      it 'denies FTP URLs' do
        expect {
          server_browser.launch('ftp://files.example.com')
        }.to raise_error(Terminalwire::Error, /denied/)
      end

      it 'denies file:// URLs' do
        expect {
          server_browser.launch('file:///etc/passwd')
        }.to raise_error(Terminalwire::Error, /denied/)
      end

      it 'denies custom schemes' do
        expect {
          server_browser.launch('custom://malicious.com')
        }.to raise_error(Terminalwire::Error, /denied/)
      end
    end
  end
end
