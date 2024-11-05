module Terminalwire::Server
  # Representation of the resources avilable to the server on the client-side. These
  # classes encapsulate the API alls to the client and provide a more Ruby-like interface.
  module Resource
    class Base < Terminalwire::Resource::Base
      private

      def command(command, **parameters)
        @adapter.write(
          event: "resource",
          name: @name,
          action: "command",
          command: command,
          parameters: parameters
        )

        response = @adapter.read
        case response.fetch(:status)
        when "success"
          response.fetch(:response)
        when "failure"
          raise Terminalwire::Error, response.inspect
        end
      end
    end

    class EnvironmentVariable
      # Accepts a list of environment variables to permit.
      def read(key:)
        command("read", key:)
      end

      def set(key:, value:)
        command("set", key:, value:)
      end
    end

    class STDOUT < Base
      def puts(data)
        command("print_line", data: data)
      end

      def print(data)
        command("print", data: data)
      end

      def flush
        # Do nothing
      end
    end

    class STDERR < STDOUT
    end

    class STDIN < Base
      def getpass
        command("read_password")
      end

      def gets
        command("read_line")
      end
    end

    class File < Base
      def read(path)
        command("read", path: path.to_s)
      end

      def write(path, content)
        command("write", path: path.to_s, content:)
      end

      def append(path, content)
        command("append", path: path.to_s, content:)
      end

      def delete(path)
        command("delete", path: path.to_s)
      end
      alias :rm :delete

      def exist?(path)
        command("exist", path: path.to_s)
      end

      def change_mode(path, mode)
        command("change_mode", path: path.to_s, mode:)
      end
      alias :chmod :change_mode
    end

    class Directory < Base
      def list(path)
        command("list", path: path.to_s)
      end
      alias :ls :list

      def create(path)
        command("create", path: path.to_s)
      end
      alias :mkdir :create

      def exist?(path)
        command("exist", path: path.to_s)
      end

      def delete(path)
        command("delete", path: path.to_s)
      end
      alias :rm :delete
    end

    class Browser < Base
      def launch(url)
        command("launch", url: url)
      end
    end
  end
end
