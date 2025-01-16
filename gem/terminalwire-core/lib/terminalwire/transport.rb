require 'uri'
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

    class WebSocket < Base
      def self.connect(url)
        uri = URI(url)
        endpoint = Async::HTTP::Endpoint.parse(uri)
        adapter = Async::WebSocket::Client.connect(endpoint)
        new(adapter)
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
        @websocket.flush
      end

      def close
        @websocket.close
      end
    end
  end
end
