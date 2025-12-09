# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Terminalwire::Server::Resource::Shell do
  let(:integration) {
    Sync::Integration.new(authority: 'shell-test.example.com') do |sync|
      # Permit specific command prefixes for testing
      sync.policy.shell.permit "echo"
      sync.policy.shell.permit "ls"
      sync.policy.shell.permit "cat"
      sync.policy.shell.permit "pwd"
      sync.policy.shell.permit "true"
      sync.policy.shell.permit "false"
      # Allow all paths for chdir testing
      sync.policy.paths.permit("**/*", mode: 0o777)
    end
  }
  let(:server_shell) { described_class.new("shell", integration.server_adapter) }

  describe '#run' do
    it 'executes a simple command and returns stdout' do
      result = server_shell.run("echo", "hello world")

      expect(result.stdout.strip).to eq("hello world")
      expect(result.stderr).to eq("")
      expect(result.exitstatus).to eq(0)
      expect(result.success?).to be true
    end

    it 'returns stderr for error output' do
      result = server_shell.run("cat", "/nonexistent/file/path")

      expect(result.stderr).to include("No such file")
      expect(result.success?).to be false
    end

    it 'returns correct exit status for failing commands' do
      result = server_shell.run("false")

      expect(result.exitstatus).to eq(1)
      expect(result.success?).to be false
    end

    it 'returns correct exit status for successful commands' do
      result = server_shell.run("true")

      expect(result.exitstatus).to eq(0)
      expect(result.success?).to be true
    end

    it 'passes multiple arguments correctly' do
      result = server_shell.run("echo", "arg1", "arg2", "arg3")

      expect(result.stdout.strip).to eq("arg1 arg2 arg3")
    end

    it 'executes command in specified directory' do
      Dir.mktmpdir do |tmpdir|
        result = server_shell.run("pwd", chdir: tmpdir)

        expect(result.stdout.strip).to eq(File.realpath(tmpdir))
      end
    end

    context 'with timeout' do
      it 'applies default timeout' do
        result = server_shell.run("echo", "fast")
        expect(result.success?).to be true
      end

      it 'respects custom timeout' do
        result = server_shell.run("echo", "test", timeout: 60)
        expect(result.success?).to be true
      end
    end
  end

  describe 'security: array-based execution prevents shell injection' do
    it 'treats shell metacharacters as literal arguments' do
      # This would be dangerous with shell interpretation:
      # "echo test && rm -rf /" would execute both commands
      # With array execution, "test && rm -rf /" is a single argument to echo
      result = server_shell.run("echo", "test && echo injected")

      # The entire string including && is treated as one argument
      expect(result.stdout.strip).to eq("test && echo injected")
    end

    it 'treats semicolons as literal characters' do
      result = server_shell.run("echo", "test; echo injected")

      expect(result.stdout.strip).to eq("test; echo injected")
    end

    it 'treats pipes as literal characters' do
      result = server_shell.run("echo", "test | cat")

      expect(result.stdout.strip).to eq("test | cat")
    end

    it 'treats backticks as literal characters' do
      result = server_shell.run("echo", "`whoami`")

      expect(result.stdout.strip).to eq("`whoami`")
    end

    it 'treats $() as literal characters' do
      result = server_shell.run("echo", "$(whoami)")

      expect(result.stdout.strip).to eq("$(whoami)")
    end
  end

  describe 'unauthorized command access' do
    let(:restricted_integration) {
      Sync::Integration.new(authority: 'restricted-shell.example.com') do |sync|
        # Only permit specific git commands
        sync.policy.shell.permit "git status"
        sync.policy.shell.permit "git log"
      end
    }
    let(:restricted_shell) { described_class.new("shell", restricted_integration.server_adapter) }

    it 'denies commands not in the allowlist' do
      expect {
        restricted_shell.run("rm", "-rf", "/")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'denies git commands not matching the prefix' do
      expect {
        restricted_shell.run("git", "push", "--force")
      }.to raise_error(Terminalwire::Error, /denied/)
    end

    it 'permits git status command' do
      # Note: This will fail if git isn't installed, but tests the permission system
      begin
        result = restricted_shell.run("git", "status")
        # If we get here without error, permission was granted
        expect(result).to be_a(described_class::Result)
      rescue Errno::ENOENT
        skip "git not installed"
      end
    end

    it 'permits git log command with additional arguments' do
      begin
        result = restricted_shell.run("git", "log", "--oneline", "-n", "1")
        expect(result).to be_a(described_class::Result)
      rescue Errno::ENOENT
        skip "git not installed"
      end
    end
  end

  describe 'chdir path entitlement' do
    let(:restricted_integration) {
      Sync::Integration.new(authority: 'chdir-restricted.example.com') do |sync|
        sync.policy.shell.permit "pwd"
        # Only permit /tmp paths
        sync.policy.paths.permit("/tmp/**/*", mode: 0o755)
      end
    }
    let(:restricted_shell) { described_class.new("shell", restricted_integration.server_adapter) }

    it 'denies chdir to unauthorized paths' do
      expect {
        restricted_shell.run("pwd", chdir: "/etc")
      }.to raise_error(Terminalwire::Error, /denied/)
    end
  end
end
