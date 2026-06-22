# frozen_string_literal: true

require "terminalwire/v2"                  # full v2 server (runtime, handler, …)
require "terminalwire/v2/server/rack"      # the v2 Rack endpoint
require "terminalwire/v2/server/dual_thor" # one Thor CLI, both protocols

# Rails `session` parity (v1 -> v2 with NO Thor app changes). v1's Rails shell
# (Terminalwire::Rails::Thor::Shell) exposes a JWT-backed `session`; the plain v2
# shell doesn't — so unchanged v1 Thor code that touches `session` (current_user,
# whoami, login) raised NoMethodError over v2. Reopen the v2 shell to provide the
# SAME session, backed by the protocol-agnostic context (file/directory/storage_path,
# which v2 implements identically). PUBLIC, not protected: Ruby 4's Forwardable —
# used by the v1 `def_delegators :shell, :session` — refuses to forward to a
# non-public method (the "forwarding to private method" warning is now a hard error).
# Terminalwire::Rails::Session is referenced lazily so this file needn't hard-depend
# on the v1 rails gem at load (it's present at call time in a dual-transition app).
Terminalwire::V2::Server::Thor::Shell.class_eval do
  def session
    @session ||= ::Terminalwire::Rails::Session.new(context: context)
  end
end

module Terminalwire
  module V2
    # Drop-in Rails integration for serving a Terminalwire CLI over BOTH the v1
    # and v2 wire on a SINGLE endpoint during the transition. The whole wiring is
    # one line in config/routes.rb:
    #
    #   require "terminalwire/v2/rails"
    #   match "/terminal", to: Terminalwire::V2::Rails.dual_terminal(MainTerminal),
    #                      via: [:get, :connect]
    #
    # A v2 client advertises the `terminalwire.v2` WebSocket subprotocol on the
    # upgrade; the dispatcher detects that (before the socket is accepted) and routes
    # to the v2 server, otherwise to the unchanged v1 handler. Same URL for both —
    # the exec launcher's `url:` never changes. `dualize` extends the Thor tree so
    # it's the SAME CLI answering on either wire, not a v2 fork.
    #
    # For a v2-only app (no v1 sub-gems), skip this and just
    # `mount Terminalwire::V2::Server::Rack.new(cli)` directly.
    module Rails
      SUBPROTOCOL = "terminalwire.v2"

      # Returns a Rack endpoint that serves `cli` over both protocols. Pass `v1:`/`v2:`
      # to override the handlers (tests, custom adapters); by default it builds the
      # stock v1 `Terminalwire::Rails::Thor` and v2 `Terminalwire::V2::Server::Rack`.
      def self.dual_terminal(cli, v1: nil, v2: nil)
        Terminalwire::V2::Server.dualize(cli)
        Dispatcher.new(
          v1: v1 || default_v1(cli),
          v2: v2 || Terminalwire::V2::Server::Rack.new(cli, verbose: verbose?, report: report)
        )
      end

      # The v2-DEFAULT endpoint: serve `cli` over v2, with no v1. Mount it the same way
      # as dual_terminal:
      #
      #   match "/terminal", to: Terminalwire::V2::Rails.terminal(MainTerminal),
      #                      via: [:get, :connect]
      #
      # It returns a version endpoint (not the bare Rack): a connection advertising the
      # `terminalwire.v2` subprotocol — and any connection that doesn't ask for another
      # version — is served by the v2 server. The endpoint is the forward-compatible
      # seam: a future v3 registers another handler here without changing the app's
      # route. (A bare Rack handed to `match to:` drops streaming output in production;
      # the endpoint, like dual_terminal's, is what Rails routing needs.)
      def self.terminal(cli, verbose: nil, report: nil)
        Terminalwire::V2::Server.dualize(cli)
        v2 = Terminalwire::V2::Server::Rack.new(
          cli,
          verbose: verbose.nil? ? verbose?() : verbose,
          report: report || self.report
        )
        VersionEndpoint.new(default: v2, by_subprotocol: { SUBPROTOCOL => v2 })
      end

      # In dev/test, show the full backtrace to the client (consider_all_requests_local,
      # like v1). In production the client sees the generic message — but the real
      # exception is still LOGGED + reported (below), never silently swallowed.
      def self.verbose?
        ::Rails.application.config.consider_all_requests_local
      rescue StandardError
        false
      end

      # Log + report unexpected command errors to Rails (mirrors the v1 handler).
      # Without this the v2 Handler drops the exception on the floor behind the
      # generic message, which is exactly what made the missing-host bug hard to find.
      def self.report
        lambda do |error|
          ::Rails.error.report(error, handled: true) if ::Rails.respond_to?(:error)
          ::Rails.logger&.error("terminalwire: #{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}")
        end
      end

      # Lazily resolve the v1 handler so this gem doesn't hard-depend on the v1
      # `terminalwire-rails` gem at load time. Apps doing the transition have it;
      # if not, fail with a clear message instead of a NameError.
      def self.default_v1(cli)
        unless defined?(Terminalwire::Rails::Thor)
          raise "terminalwire/v2/rails: the v1 handler (Terminalwire::Rails::Thor) " \
                "isn't loaded. Add the v1 `terminalwire-rails` gem, or pass v2:-only " \
                "and mount Terminalwire::V2::Server::Rack directly for a v2-only app."
        end
        Terminalwire::Rails::Thor.new(cli)
      end

      # Routes a WebSocket upgrade to the v1 or v2 handler by inspecting the
      # advertised subprotocol on the Rack env — no socket is accepted until the
      # branch is chosen, so a connection only ever reaches one handler.
      class Dispatcher
        def initialize(v1:, v2:)
          @v1 = v1
          @v2 = v2
        end

        def call(env)
          protos = env["HTTP_SEC_WEBSOCKET_PROTOCOL"].to_s.split(/,\s*/)
          (protos.include?(SUBPROTOCOL) ? @v2 : @v1).call(env)
        end
      end

      # Routes a WebSocket upgrade to a handler by the version subprotocol it advertises,
      # falling back to `default` (v2) when none matches — the forward-compatible seam for
      # registering future protocol versions. Same Rack-endpoint shape as Dispatcher, so
      # Rails `match to:` hands the connection off correctly in production.
      class VersionEndpoint
        def initialize(default:, by_subprotocol: {})
          @default = default
          @by_subprotocol = by_subprotocol
        end

        def call(env)
          protos = env["HTTP_SEC_WEBSOCKET_PROTOCOL"].to_s.split(/,\s*/)
          handler = protos.lazy.filter_map { |proto| @by_subprotocol[proto] }.first || @default
          handler.call(env)
        end
      end
    end
  end
end
