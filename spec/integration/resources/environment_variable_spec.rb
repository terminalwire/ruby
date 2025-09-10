# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::EnvironmentVariable do
  let(:integration) { 
    Sync::Integration.new(authority: 'env-test.example.com') do |sync|
      sync.policy.environment_variables.permit("TEST_VAR")
      sync.policy.environment_variables.permit("HOME")
      sync.policy.environment_variables.permit("USER")
      sync.policy.environment_variables.permit("PATH")
      sync.policy.environment_variables.permit("EMPTY_VAR")
      sync.policy.environment_variables.permit("DEFINITELY_NONEXISTENT_VAR_12345")
    end
  }
  let(:server_env) { described_class.new("environment_variable", integration.server_adapter) }

  describe '#read' do
    it 'reads existing environment variable' do
      ENV['TEST_VAR'] = 'test_value'
      
      result = server_env.read('TEST_VAR')
      
      expect(result).to eq('test_value')
    end

    it 'returns nil for non-existent variable' do
      result = server_env.read('DEFINITELY_NONEXISTENT_VAR_12345')
      
      expect(result).to be_nil
    end

    it 'reads empty string values correctly' do
      ENV['EMPTY_VAR'] = ''
      
      result = server_env.read('EMPTY_VAR')
      
      expect(result).to eq('')
    end

    it 'reads system environment variables like HOME' do
      result = server_env.read('HOME')
      
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end

  describe 'unauthorized access' do
    let(:restricted_integration) { 
      Sync::Integration.new(authority: 'restricted-env.example.com') do |sync|
        sync.policy.environment_variables.permit("HOME")
      end
    }
    let(:restricted_env) { described_class.new("environment_variable", restricted_integration.server_adapter) }

    it 'denies reading unauthorized environment variables' do
      expect {
        restricted_env.read('PATH')
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies reading sensitive system variables' do
      expect {
        restricted_env.read('USER')
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies reading custom variables' do
      ENV['SECRET_API_KEY'] = 'super-secret'
      
      expect {
        restricted_env.read('SECRET_API_KEY')
      }.to raise_error(Terminalwire::Error, /denied/)
    end
  end
end