# frozen_string_literal: true

require "thor"

module Terminalwire2
  module Server
    # Thor integration. Including this in a Thor CLI routes all of Thor's I/O —
    # say, ask, yes?, and bare puts/print/gets inside commands — through the
    # Terminalwire Context instead of the server's real $stdin/$stdout. This is
    # what lets you keep writing an ordinary Thor CLI while it runs on the client.
    module Thor
      # An IO-shaped adapter so Thor's shell writes land on the client.
      class IO
        def initialize(context, stream)
          @context = context
          @stream = stream
        end

        def print(*args)
          args.each { |arg| @context.print(arg.to_s, stream: @stream) }
          nil
        end

        def write(*args)
          args.sum { |arg| s = arg.to_s; @context.print(s, stream: @stream); s.bytesize }
        end

        def <<(arg)
          @context.print(arg.to_s, stream: @stream)
          self
        end

        def puts(*args)
          if args.empty?
            @context.print("\n", stream: @stream)
          else
            args.flatten.each { |arg| @context.print("#{arg}\n", stream: @stream) }
          end
          nil
        end

        def flush = self
        def sync = true
        def sync=(value); value; end
        def tty? = false
      end

      # Bare puts/print/gets inside Thor commands. Defined in a module so Thor's
      # method_added hook never sees them and they are not registered as commands.
      module Helpers
        def puts(*args) = shell.context.puts(*args.flatten.map(&:to_s))
        def print(*args) = args.each { |arg| shell.context.print(arg.to_s) }
        def warn(*args) = args.each { |arg| shell.context.warn(arg.to_s) }
        def gets = shell.context.gets
        def getpass = shell.context.getpass
        def context = shell.context
      end

      class Shell < ::Thor::Shell::Basic
        attr_reader :context

        def initialize(context, *args, **kwargs, &block)
          @context = context
          super(*args, **kwargs, &block)
        end

        protected

        def stdout = @stdout ||= IO.new(@context, :stdout)
        def stderr = @stderr ||= IO.new(@context, :stderr)

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
