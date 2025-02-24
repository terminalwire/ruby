require 'thor'

module Terminalwire
  module Server
    module Thor
      class Shell < ::Thor::Shell::Basic
        extend Forwardable

        # Encapsulates all of the IO resources for a Terminalwire adapter.
        attr_reader :context

        def_delegators :context,
          :stdin, :stdout, :stderr

        def initialize(context, *, **, &)
          @context = context
          super(*,**,&)
        end
      end

      def self.included(base)
        base.extend ClassMethods

        # I have to do this in a block to deal with some of Thor's DSL
        base.class_eval do
          extend Forwardable

          protected

          no_commands do
            def_delegators :shell,
              :context
            def_delegators :context,
              :stdout, :stdin, :stderr, :browser
            def_delegators :stdout,
              :puts, :print
            def_delegators :stdin,
              :gets, :getpass

            # Prints text to the standard error stream.
            def warn(...)
              stderr.puts(...)
            end

            # Prints text to the standard error stream and exits the program.
            def fail(...)
              stderr.puts(...)
              context.exit 1
            ensure
              super
            end
            # Feels more naturual to call `client.files` etc. from
            # the serve since it's more apparent that it's a client.
            alias :client :context
          end
        end
      end

      module ClassMethods
        def terminalwire(arguments:, context:)
          # I have to manually hack into the Thor dispatcher to get access to the instance
          # of the CLI so I can slap the Rails helper methods in there, or other helpes
          # raise [context.inspect, arguments.inspect, self.inspect].inspect
          dispatch(nil, arguments.dup, nil, shell: terminalwire_shell(context)) do |instance|
            yield instance
          end
        end

        def terminalwire_shell(context)
          Terminalwire::Server::Thor::Shell.new(context)
        end
      end
    end
  end
end
