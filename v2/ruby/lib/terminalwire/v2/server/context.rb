# frozen_string_literal: true

module Terminalwire::V2
  module Server
    # The server's handle on the client's machine. CLI code calls these methods
    # (puts, gets, file.read, ...) and the Context turns them into protocol frames
    # via the Runtime. Output is one-way; input and filesystem ops are synchronous
    # request/response.
    class Context
      def initialize(runtime)
        @runtime = runtime
        @stdout_sid = nil
        @stderr_sid = nil
        @request = {}
      end

      # The incoming HTTP connection profile, captured at the WebSocket upgrade
      # (the Rack adapter sets it): { host:, ip:, user_agent:, headers: }. The
      # client identifies itself in headers — chiefly a real User-Agent — so server
      # code can see who connected (and a `terminalwire about` can light it up).
      attr_accessor :request

      # The client's real IP (through Fly/proxies), its User-Agent, and the raw
      # incoming HTTP headers. nil/empty when unknown (e.g. non-HTTP transports).
      def remote_ip   = @request[:ip]
      def user_agent  = @request[:user_agent]
      def http_headers = @request[:headers] || {}

      # The client build version, parsed from the User-Agent
      # ("terminalwire-exec/<version> (…)"). The version is a client-reported fact
      # in a header, never derived from the URL. nil if the client sent no UA.
      def client_version
        user_agent && user_agent[%r{terminalwire-exec/(\S+)}, 1]
      end

      # The client's live terminal (rows/cols/tty?/color?), kept current by the
      # runtime's read pump as resize frames arrive.
      def terminal = @runtime.terminal

      # The program name + arguments the client launched with (from the hello).
      # CLI parsers (OptionParser, Thor, GLI, …) consume `program_arguments`.
      def program_name = @runtime.program && @runtime.program["name"]
      def program_arguments = Array(@runtime.program && @runtime.program["args"])

      # The entitlement the client granted this session: its authority (origin),
      # the path globs it will allow writes within, and the permitted schemes/env
      # vars. The CLIENT enforces this; here it's a read-only view so server code
      # can stay inside the sandbox (e.g. learn where it may persist a file).
      def entitlement = @runtime.entitlement

      # The capability set negotiated for this session — the intersection the
      # client and server agreed on in the handshake. Branch on this to offer
      # optional features only when the connected client supports them.
      def capabilities = @runtime.connection.capabilities

      # The client directory this origin may persist files into — its sandbox —
      # derived from the first granted path glob (".../**" -> "..."). Returns nil
      # if no writable path was granted. Used like:
      #
      #   context.file.write("#{context.storage_path}/session.json", data)
      def storage_path
        glob = entitlement && entitlement.dig("paths", 0, "glob")
        glob && glob.sub(%r{/\*\*\z}, "")
      end

      # Register a callback fired when the client's window resizes.
      def on_resize(&block) = @runtime.on_resize(&block)

      # Output is flow-controlled and chunked by the runtime: write_data sizes each
      # data frame to the client's available credit and blocks when the window is
      # exhausted, so a fast server can't outrun a slow client.
      def print(data, stream: :stdout)
        sid = stream == :stderr ? (@stderr_sid ||= open(:stderr)) : (@stdout_sid ||= open(:stdout))
        @runtime.write_data(sid, data.to_s)
      end

      def puts(data = "", stream: :stdout)
        print("#{data}\n", stream: stream)
      end

      def warn(data = "")
        puts(data, stream: :stderr)
      end

      def stdin
        @stdin ||= Stdin.new(@runtime)
      end

      # Convenience delegators (Thor's shell uses these).
      def gets = stdin.gets
      def getpass = stdin.getpass

      def env(name)
        @runtime.request(:env, :read, { "name" => name.to_s })
      end

      # Read keystrokes for the duration of the block: the client puts its terminal
      # in `mode` and streams keypresses, restoring it when the block exits (even
      # on error). Foundation for REPLs and interactive TUIs.
      #
      #   mode: :raw    — char-at-a-time, no echo, signals as bytes (TUIs)
      #   mode: :cbreak — char-at-a-time, echo + signal keys on (single-key y/n)
      #
      #   context.raw_input { |keys| keys.each { |bytes| handle(bytes) } }
      def raw_input(mode: Protocol::Mode::RAW)
        sid = @runtime.open_raw_input(mode: mode.to_s)
        yield RawInput.new(@runtime, sid)
      ensure
        @runtime.close_raw_input(sid) if sid
      end

      # Single-keypress read with echo + signal keys left on (cbreak): the y/n
      # prompt case. Returns the first byte(s) the user types.
      def read_key
        raw_input(mode: Protocol::Mode::CBREAK) { |keys| return keys.read }
      end

      # Query the client's terminal with a control sequence and return its reply
      # (e.g. cursor-position report "\e[6n" -> "\e[row;colR"). The client writes
      # the query to its tty and reads the terminal's response. Used by advanced
      # TUI libraries that probe the terminal. Support is advertised via the
      # terminal-query capability (see #capabilities); a client without a tty
      # answers with an io error. (Enforcement isn't wired yet — this issues the
      # request regardless — so check #capabilities yourself if that matters.)
      def query_terminal(sequence, timeout: 1.0)
        @runtime.request(:terminal, :query, { "sequence" => sequence.b, "timeout" => timeout })
      end

      def file
        @file ||= File.new(@runtime)
      end

      def directory
        @directory ||= Directory.new(@runtime)
      end

      def browser
        @browser ||= Browser.new(@runtime)
      end

      def exit(status = 0)
        @runtime.emit(Frames.exit(status: status))
      end

      private

      def open(stream)
        @runtime.open_output(stream)
      end

      # Reads keystroke chunks from a raw input stream. #read returns the next
      # chunk (or nil when the stream closes); #each yields until close.
      class RawInput
        def initialize(runtime, sid)
          @runtime = runtime
          @sid = sid
        end

        def read = @runtime.read_raw(@sid)

        def each
          return enum_for(:each) unless block_given?

          while (bytes = read)
            yield bytes
          end
        end
      end

      # Resource facades — thin request wrappers with a Ruby-ish interface.

      class Stdin
        DEFAULT_CHUNK = 64 * 1024

        def initialize(runtime) = @runtime = runtime

        def gets = @runtime.request(:stdin, :gets)
        def getpass = @runtime.request(:stdin, :getpass)

        # Is the client's stdin a terminal (vs a pipe/file)? Branch on this to
        # decide between prompting and draining piped data.
        def tty? = @runtime.terminal.stdin.tty?

        # Pull up to `n` bytes from the client's stdin. Returns [data, eof].
        def read_chunk(n = DEFAULT_CHUNK)
          response = @runtime.request(:stdin, :read_chunk, { "n" => n })
          [response["data"] || "".b, response["eof"]]
        end

        # Drain the client's stdin to EOF (for piped input).
        def read
          buffer = +"".b
          loop do
            data, eof = read_chunk
            buffer << data.b # force binary: chunks may arrive as UTF-8 (msgpack
            break if eof     # str) or binary (bin); mixing them would raise.
          end
          buffer
        end

        # Yield each chunk as it arrives until EOF (streaming without buffering).
        def each_chunk(n = DEFAULT_CHUNK)
          return enum_for(:each_chunk, n) unless block_given?

          loop do
            data, eof = read_chunk(n)
            yield data unless data.empty?
            break if eof
          end
        end
      end

      class File
        def initialize(runtime) = @runtime = runtime
        def read(path)            = @runtime.request(:file, :read, { "path" => path.to_s })
        def write(path, content)  = @runtime.request(:file, :write, { "path" => path.to_s, "content" => content })
        def append(path, content) = @runtime.request(:file, :append, { "path" => path.to_s, "content" => content })
        def delete(path)          = @runtime.request(:file, :delete, { "path" => path.to_s })
        def exist?(path)          = @runtime.request(:file, :exist, { "path" => path.to_s })
        # chmod the file to `mode` (an integer like 0o755). The client requires an
        # rw grant on the path and rejects a missing mode.
        def change_mode(path, mode) = @runtime.request(:file, :change_mode, { "path" => path.to_s, "mode" => mode })
      end

      class Directory
        def initialize(runtime) = @runtime = runtime
        def list(path)          = @runtime.request(:directory, :list, { "path" => path.to_s })
        alias_method :ls, :list # v1 commands call `directory.ls`; same op, no protocol change
        def create(path)        = @runtime.request(:directory, :create, { "path" => path.to_s })
        def exist?(path)        = @runtime.request(:directory, :exist, { "path" => path.to_s })
        def delete(path)        = @runtime.request(:directory, :delete, { "path" => path.to_s })
      end

      class Browser
        def initialize(runtime) = @runtime = runtime
        def launch(url)         = @runtime.request(:browser, :launch, { "url" => url.to_s })
      end
    end
  end
end
