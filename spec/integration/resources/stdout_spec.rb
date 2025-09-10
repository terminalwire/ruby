# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::STDOUT do
  let(:integration) { 
    Sync::Integration.new(authority: 'stdout-test.example.com') 
  }
  let(:server_stdout) { described_class.new("stdout", integration.server_adapter) }

  describe '#print' do
    it 'prints data to stdout through client' do
      expect { server_stdout.print("Hello from server") }.to output("Hello from server").to_stdout
    end
  end

  describe '#puts' do
    it 'prints line with newline to stdout through client' do
      expect { server_stdout.puts("Hello line") }.to output("Hello line\n").to_stdout
    end
  end

  describe '#flush' do
    it 'does nothing and succeeds' do
      expect { server_stdout.flush }.not_to raise_error
    end
  end

  describe 'entitlements' do
    let(:restricted_integration) { 
      Sync::Integration.new(authority: 'restricted-stdout.example.com') 
      # No special permissions configured - IO should still work
    }
    let(:restricted_stdout) { described_class.new("stdout", restricted_integration.server_adapter) }

    it 'allows stdout access regardless of entitlements' do
      expect { restricted_stdout.print("Always works") }.to output("Always works").to_stdout
    end

    it 'allows puts access regardless of entitlements' do
      expect { restricted_stdout.puts("Always works") }.to output("Always works\n").to_stdout
    end
  end
end