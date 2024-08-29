module Terminalwire
  module Transport
    class Base
      def initialize
        raise NotImplementedError, "This is an abstract base class"
      end

      def read
        raise NotImplementedError, "Subclass must implement #read"
      end

      def write(data)
        raise NotImplementedError, "Subclass must implement #write"
      end

      def close
        raise NotImplementedError, "Subclass must implement #close"
      end
    end

    class WebSocket
      def initialize(websocket)
        @websocket = websocket
      end

      def read
        @websocket.read&.buffer
      end

      def write(data)
        @websocket.write(data)
      end

      def close
        @websocket.close
      end
    end

    class Socket < Base
      def initialize(socket)
        @socket = socket
      end

      def read
        length = @socket.read(4)
        return nil if length.nil?
        length = length.unpack('L>')[0]
        @socket.read(length)
      end

      def write(data)
        length = [data.bytesize].pack('L>')
        @socket.write(length + data)
      end

      def close
        @socket.close
      end
    end
  end
end