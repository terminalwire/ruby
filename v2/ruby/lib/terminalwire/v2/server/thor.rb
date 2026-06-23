# frozen_string_literal: true

require "thor"

module Terminalwire::V2
  module Server
    # Thor integration. Including this in a Thor CLI routes all of Thor's I/O —
    # say, ask, yes?, and bare puts/print/gets inside commands — through the
    # Terminalwire Context instead of the server's real $stdin/$stdout. This is
    # what lets you keep writing an ordinary Thor CLI while it runs on the client.
    #
    # Thor needs this dedicated adapter (rather than the generic Server.redirect)
    # because its shell captures the output streams at construction instead of
    # reading the $stdout/$stderr globals at call time. The byte plumbing is the
    # shared Server::IO.
    module Thor
      # Bare puts/print/gets inside Thor commands. Defined in a module so Thor's
      # method_added hook never sees them and they are not registered as commands.
      module Helpers
        def puts(*args) = shell.context.puts(*args.flatten.map(&:to_s))
        def print(*args) = args.each { |arg| shell.context.print(arg.to_s) }
        def warn(*args) = args.each { |arg| shell.context.warn(arg.to_s) }
        def gets = shell.context.gets
        def getpass = shell.context.getpass
        def context = shell.context
        # The client-side resources, exposed on the CLI instance like v1 (so a Thor
        # command can call `browser.launch(url)`, `file.read(path)`, `env("HOME")`).
        def browser = shell.context.browser
        def file = shell.context.file
        def directory = shell.context.directory
        def env(name) = shell.context.env(name)
        def client = shell.context
      end

      class Shell < ::Thor::Shell::Basic
        attr_reader :context

        def initialize(context, *args, **kwargs, &block)
          @context = context
          super(*args, **kwargs, &block)
        end

        protected

        def stdout = @stdout ||= Server::IO.new(@context, :stdout)
        def stderr = @stderr ||= Server::IO.new(@context, :stderr)

        # Override Thor's line-editor input (which hardcodes $stdin) to read from
        # the client through the context. Fixes ask, yes?, no?, and passwords.
        def ask_simply(statement, color, options)
          default = options[:default]
          message = [statement, ("(#{default})" if default), nil].uniq.join(" ")
          stdout.print(prepare_message(message, *Array(color)))

          result = options.fetch(:echo, true) ? context.gets : context.getpass
          return unless result

          result = result.strip
          default && result == "" ? default : result
        end
      end

      def self.included(base)
        base.extend ClassMethods
        base.include Helpers
      end

      module ClassMethods
        # Dispatch a CLI invocation with a Terminalwire-backed shell.
        def terminalwire(arguments:, context:)
          dispatch(nil, arguments.dup, nil, shell: Shell.new(context)) do |instance|
            yield instance if block_given?
          end
        end
      end
    end
  end
end
