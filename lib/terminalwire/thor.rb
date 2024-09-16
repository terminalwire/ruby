module Terminalwire
  module Thor
    class Shell < ::Thor::Shell::Basic
      extend Forwardable

      # Encapsulates all of the IO resources for a Terminalwire adapter.
      attr_reader :context, :session

      def_delegators :context,
        :stdin, :stdout, :stderr

      def initialize(context, *, **, &)
        @context = context
        @session = Terminalwire::Rails::Session.new(context:)
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
            :context, :session
          def_delegators :context,
            :stdout, :stdin, :stderr, :browser
          def_delegators :stdout,
            :puts, :print
          def_delegators :stdin,
            :gets
        end
      end
    end

    module ClassMethods
      def start(given_args = ARGV, config = {})
        context = config.delete(:context)
        config[:shell] = Shell.new(context) if context
        super(given_args, config)
      end
    end
  end
end
