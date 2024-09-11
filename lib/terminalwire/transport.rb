require 'uri'
require 'socket'
require 'async/websocket/client'

module Terminalwire
  module Transport
    class Base
      def self.connect(url)
        raise NotImplementedError, "Subclass must implement .connect"
      end

      def self.listen(url)
        raise NotImplementedError, "Subclass must implement .listen"
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

    class TCP < Base
      def self.connect(url)
        uri = URI(url)
        new(TCPSocket.new(uri.host, uri.port))
      end

      def self.listen(url)
        uri = URI(url)
        new(TCPServer.new(uri.host, uri.port))
      end

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

    class Unix < Base
      def self.connect(url)
        uri = URI(url)
        new(UNIXSocket.new(uri.path))
      end

      def self.listen(url)
        uri = URI(url)
        new(UNIXServer.new(uri.path))
      end

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

    class WebSocket < Base
      def self.connect(url)
        uri = URI(url)
        endpoint = Async::HTTP::Endpoint.parse(uri)
        adapater = Async::WebSocket::Client.connect(endpoint)
        new(adapater)
      end

      def self.listen(url)
        # This would need to be implemented with a WebSocket server library
        raise NotImplementedError, "WebSocket server not implemented"
      end

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
  end
end
