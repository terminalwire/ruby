# frozen_string_literal: true

module Terminalwire::V2
  module Server
    # The framework-agnostic server entrypoint: performs the handshake, runs your
    # CLI with a Terminalwire-backed context, handles errors, and exits the client.
    # A Rails or Rack adapter just builds a transport and calls this.
    #
    # Your CLI can be ANY of:
    #   * a block / callable run(context, args) — works with OptionParser, GLI,
    #     dry-cli, or hand-rolled parsing. The block runs inside `Server.redirect`,
    #     so $stdout/$stderr/$stdin and bare puts/gets already target the client.
    #   * a Thor class via `cli_class:` (it gets Thor's dedicated shell adapter).
    #
    #   # OptionParser (or anything using the standard IO globals):
    #   Handler.new do |ctx, args|
    #     opts = {}
    #     OptionParser.new { |o| o.on("--name NAME") { |v| opts[:name] = v } }.parse!(args)
    #     puts "hello #{opts[:name]}"
    #   end
    #
    #   # Thor:
    #   Handler.new(cli_class: MyThorCLI)
    class Handler
      DEFAULT_ERROR_MESSAGE = "An error occurred. Please try again."

      # @param cli_class [Class, nil] a Thor CLI that `include`s Server::Thor
      # @param run [#call, nil] a callable (context, args) for non-Thor CLIs
      # @param report [#call, nil] optional callable invoked with unexpected errors
      # @param verbose [Boolean] show full backtraces to the client (dev only)
      # @yield [context, args] block form of `run:`
      def initialize(cli_class: nil, run: nil, report: nil, verbose: false,
                     error_message: DEFAULT_ERROR_MESSAGE, &block)
        @cli_class = cli_class
        @run = run || block
        @report = report
        @verbose = verbose
        @error_message = error_message

        return if @cli_class || @run

        raise ArgumentError, "provide a Thor cli_class:, a run: callable, or a block"
      end

      # Run one session over the given transport. Returns the exit status.
      # `request` is the incoming HTTP connection profile from the Rack env
      # ({ host:, ip:, user_agent:, headers: }) — threaded in so URL helpers can use
      # the host (v1 set `cli.default_url_options[:host]` the same way) and so server
      # code / `about` can see who connected.
      def call(transport:, request: {})
        runtime = Runtime.new(transport: transport).handshake
        context = Context.new(runtime)
        context.request = request
        arguments = context.program_arguments
        status = 0

        begin
          begin
            dispatch(context, arguments, request[:host])
          rescue Interrupt, Interrupted
            status = 130
          rescue StandardError => e
            status = handle_error(e, context)
          ensure
            # Teardown must not be interrupted. A late Ctrl-C (delivered as an async
            # Interrupted via Thread#raise) landing here would abort the exit-frame
            # write or runtime close and hang the client — the very failure the
            # interrupt machinery exists to avoid. Mask async interrupts for the
            # duration so the exit frame always flushes and the runtime always closes.
            Thread.handle_interrupt(Interrupt => :never, Interrupted => :never) do
              context.exit(status)
              runtime.close
            end
          end
        rescue Interrupt, Interrupted
          # An interrupt that fired in a rescue clause above, before the mask took
          # hold, surfaces here. Teardown still ran in the ensure, so just report it.
          status = 130
        end

        status
      end

      private

      # Route to the Thor adapter or the generic redirect-based runner. `host`, when
      # present, is set on the per-session Thor instance so Rails URL helpers resolve
      # (instance-level, like v1 — no shared class-global to race across sessions).
      def dispatch(context, arguments, host = nil)
        if @cli_class
          @cli_class.terminalwire(arguments: arguments, context: context) do |cli|
            cli.default_url_options[:host] = host if host && cli.respond_to?(:default_url_options)
          end
        else
          # Generic path: point the global IO streams at the client, then run the
          # user's callable. OptionParser/GLI/dry-cli/bare puts all Just Work.
          Server.redirect(context, argv: arguments) do
            @run.call(context, arguments)
          end
        end
      end

      def handle_error(error, context)
        # A denied resource op means the client refused the grant: show an actionable
        # message (the client also prints the exact `terminalwire-policy … --approve`
        # locally) instead of the scary generic one — and don't report it (it's a
        # consent decision, not a bug).
        if denied_error?(error)
          context.warn("Terminalwire couldn't manage your install — it needs filesystem " \
                       "access you haven't granted (#{error.message}). Your client printed " \
                       "the `terminalwire-policy … --approve` command to grant it.")
        # Thor's own user-facing errors (unknown command, bad args) are friendly
        # already — pass them through verbatim. OptionParser's are too.
        elsif friendly_error?(error)
          context.warn(error.message)
        else
          @report&.call(error)
          context.warn(@verbose ? backtrace(error) : @error_message)
        end
        1
      end

      def denied_error?(error)
        error.is_a?(ResponseError) && error.code == "denied"
      end

      def friendly_error?(error)
        (defined?(::Thor::Error) && error.is_a?(::Thor::Error)) ||
          (defined?(::OptionParser::ParseError) && error.is_a?(::OptionParser::ParseError))
      end

      def backtrace(error)
        "#{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}"
      end
    end
  end
end
