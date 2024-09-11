module Terminalwire
  module Thor
    class Shell < ::Thor::Shell::Basic
      extend Forwardable

      # Encapsulates all of the IO devices for a Terminalwire adapter.
      attr_reader :session

      def_delegators :@session, :stdin, :stdout, :stderr

      def initialize(session)
        @session = session
        super()
      end
    end

    def self.included(base)
      base.extend ClassMethods

      # I have to do this in a block to deal with some of Thor's DSL
      base.class_eval do
        extend Forwardable

        protected

        no_commands do
          def_delegators :shell, :session
          def_delegators :session, :stdout, :stdin, :stderr, :browser
          def_delegators :stdout, :puts, :print
          def_delegators :stdin, :gets
        end
      end
    end

    module ClassMethods
      def start(given_args = ARGV, config = {})
        session = config.delete(:session)
        config[:shell] = Shell.new(session) if session
        super(given_args, config)
      end
    end
  end
end
