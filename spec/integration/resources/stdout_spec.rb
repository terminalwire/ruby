# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDOUT do
  let(:integration) { 
    Sync::Integration.new(authority: 'stdout-test.example.com') 
  }
  let(:server_stdout) { described_class.new("stdout", integration.server_adapter) }

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