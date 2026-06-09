# frozen_string_literal: true

require_relative "thor" # reuse the v2 Shell + Helpers

module Terminalwire::V2
  module Server
    # ONE Thor CLI, BOTH protocols. Apply `Server.dualize(MyCLI)` to a Thor class
    # that already includes the v1 `Terminalwire::Thor` adapter, and it runs
    # unchanged over the v1 AND v2 wire. This works because both servers invoke a
    # CLI through the SAME entry — `cli_class.terminalwire(arguments:, context:)` —
    # and both contexts expose the same I/O surface (puts/print/warn/gets/getpass).
    #
    # The adapter:
    #   - its single `terminalwire` entry builds the v2 Shell for a v2 context and
    #     otherwise delegates to the v1 adapter via `super` (preserving the v1/rails
    #     shell exactly);
    #   - its helpers route bare puts/print/warn/gets/getpass through the active
    #     `shell.context`, which is whichever protocol's context is live.
    module DualThor
      def self.included(base)
        base.extend ClassMethods
        base.include Terminalwire::V2::Server::Thor::Helpers
      end

      module ClassMethods
        def terminalwire(arguments:, context:, &block)
          if context.is_a?(Terminalwire::V2::Server::Context)
            dispatch(nil, arguments.dup, nil, shell: Terminalwire::V2::Server::Thor::Shell.new(context)) do |instance|
              block.call(instance) if block
            end
          else
            super # v1 adapter's terminalwire (its own shell)
          end
        end
      end
    end

    # Walk a Thor class + its subcommand tree, making every command class respond to
    # both protocols. Idempotent. Returns the class so it reads as a transform.
    def self.dualize(klass, seen = {})
      return klass if seen[klass]
      seen[klass] = true
      klass.include(DualThor) unless klass.include?(DualThor)
      klass.subcommand_classes.each_value { |sub| dualize(sub, seen) } if klass.respond_to?(:subcommand_classes)
      klass
    end
  end
end
