# frozen_string_literal: true

module Terminalwire2
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
      end

      # The client's live terminal (rows/cols/tty?/color?), kept current by the
      # runtime's read pump as resize frames arrive.
      def terminal = @runtime.terminal

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

      def gets
        @runtime.request(:stdin, :gets)
      end

      def getpass
        @runtime.request(:stdin, :getpass)
      end

      def env(name)
        @runtime.request(:env, :read, { "name" => name.to_s })
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

      # Resource facades — thin request wrappers with a Ruby-ish interface.

      class File
        def initialize(runtime) = @runtime = runtime
        def read(path)            = @runtime.request(:file, :read, { "path" => path.to_s })
        def write(path, content)  = @runtime.request(:file, :write, { "path" => path.to_s, "content" => content })
        def append(path, content) = @runtime.request(:file, :append, { "path" => path.to_s, "content" => content })
        def delete(path)          = @runtime.request(:file, :delete, { "path" => path.to_s })
        def exist?(path)          = @runtime.request(:file, :exist, { "path" => path.to_s })
      end

      class Directory
        def initialize(runtime) = @runtime = runtime
        def list(path)          = @runtime.request(:directory, :list, { "path" => path.to_s })
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
