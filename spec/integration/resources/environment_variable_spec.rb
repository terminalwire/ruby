# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::EnvironmentVariable do
  let(:integration) { 
    Sync::Integration.new(authority: 'env-test.example.com') do |sync|
      # Allow specific environment variables for testing
      sync.policy.environment_variables.permit("TEST_VAR")
      sync.policy.environment_variables.permit("HOME")
      sync.policy.environment_variables.permit("USER")
      sync.policy.environment_variables.permit("PATH")
      sync.policy.environment_variables.permit("DEFINITELY_NONEXISTENT_VAR_12345")
    end
  }
  let(:server_env) { described_class.new("environment_variable", integration.server_adapter) }

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