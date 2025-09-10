# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDERR do
  let(:integration) { 
    Sync::Integration.new(authority: 'stderr-test.example.com') 
  }
  let(:server_stderr) { described_class.new("stderr", integration.server_adapter) }

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