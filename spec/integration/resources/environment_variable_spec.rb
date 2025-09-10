# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::EnvironmentVariable do
  let(:sync_adapter) { SyncAdapter.new }
  let(:server_env) { described_class.new("environment_variable", sync_adapter) }

  before do
    # Create policy that allows specific environment variables
    entitlement = Terminalwire::Client::Entitlement::Policy.resolve(authority: 'env-test.example.com').tap do |policy|
      policy.environment_variables.permit("TEST_VAR")
      policy.environment_variables.permit("HOME")
      policy.environment_variables.permit("USER")
      policy.environment_variables.permit("PATH")
      policy.environment_variables.permit("DEFINITELY_NONEXISTENT_VAR_12345")
    end

    # Setup client resources
    client_handler = Terminalwire::Client::Resource::Handler.new(adapter: sync_adapter.client_adapter, entitlement: entitlement) do |handler|
      handler << Terminalwire::Client::Resource::EnvironmentVariable
    end
    
    sync_adapter.connect_client(client_handler)
  end

  describe '#read' do
    it 'reads existing environment variable through client' do
      ENV['TEST_VAR'] = 'test_value'
      
      result = server_env.read('TEST_VAR')
      
      expect(result).to eq('test_value')
    end

    it 'returns nil for non-existent variable' do
      result = server_env.read('DEFINITELY_NONEXISTENT_VAR_12345')
      
      expect(result).to be_nil
    end

    it 'reads standard environment variables' do
      result = server_env.read('HOME')
      
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end
end