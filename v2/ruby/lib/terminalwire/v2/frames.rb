# frozen_string_literal: true

module Terminalwire::V2
  # Builders for each frame type. Keep frame construction in one place so the wire
  # shape is defined once. All builders return a Hash with string keys.
  module Frames
    module_function

    def hello(protocol:, capabilities:, program:, entitlement:, terminal: DEFAULT_TERMINAL, flow: DEFAULT_FLOW)
      {
        "t" => Protocol::Type::HELLO, "sid" => Protocol::CONTROL_SID,
        "protocol" => protocol, "capabilities" => capabilities,
        "program" => program, "entitlement" => entitlement,
        "terminal" => terminal, "flow" => flow
      }
    end

    # The client's initial flow-control offer: how many bytes of output it will
    # accept per stream before the server must wait for a window_adjust.
    DEFAULT_FLOW = { "window" => Protocol::DEFAULT_WINDOW }.freeze

    # Client -> server: extend the output window for a stream by `bytes`.
    def window_adjust(sid:, bytes:)
      { "t" => Protocol::Type::WINDOW_ADJUST, "sid" => sid, "bytes" => bytes }
    end

    # The client's terminal at connect time (structured per TERMINAL.md: per-stream
    # kinds + a device block); resize/mode frames update the device thereafter.
    DEFAULT_TERMINAL = {
      "stdin" => { "kind" => "tty" },
      "stdout" => { "kind" => "tty" },
      "stderr" => { "kind" => "tty" },
      "device" => {
        "cols" => 80, "rows" => 24, "xpixels" => 0, "ypixels" => 0,
        "term" => "", "color" => "none", "encoding" => "UTF-8", "mode" => "cooked"
      }
    }.freeze

    # Generic async terminal signal (client -> server). resize/interrupt are the
    # named variants; collapsing them into one frame type keeps the protocol small.
    def signal(name, payload = {})
      { "t" => Protocol::Type::SIGNAL, "sid" => Protocol::CONTROL_SID, "name" => name }.merge(payload)
    end

    def resize(cols:, rows:)
      signal(Protocol::Signal::RESIZE, { "cols" => cols, "rows" => rows })
    end

    def interrupt
      signal(Protocol::Signal::INTERRUPT)
    end

    def welcome(protocol:, capabilities:)
      {
        "t" => Protocol::Type::WELCOME, "sid" => Protocol::CONTROL_SID,
        "protocol" => protocol, "capabilities" => capabilities
      }
    end

    def incompatible(supported:, message:)
      # Normalize to string keys so every wire frame is uniformly string-keyed
      # (the negotiator hands us a symbol-keyed Ruby hash).
      min = supported[:min] || supported["min"]
      max = supported[:max] || supported["max"]
      {
        "t" => Protocol::Type::INCOMPATIBLE, "sid" => Protocol::CONTROL_SID,
        "supported" => { "min" => min, "max" => max }, "message" => message
      }
    end

    def exit(status:)
      { "t" => Protocol::Type::EXIT, "sid" => Protocol::CONTROL_SID, "status" => status }
    end

    def open(sid:, stream:, mode: nil)
      frame = { "t" => Protocol::Type::OPEN, "sid" => sid, "stream" => stream }
      frame["mode"] = mode if mode # input streams carry the line-discipline mode
      frame
    end

    def data(sid:, bytes:)
      { "t" => Protocol::Type::DATA, "sid" => sid, "bytes" => bytes.b }
    end

    def close(sid:)
      { "t" => Protocol::Type::CLOSE, "sid" => sid }
    end

    def request(sid:, resource:, method:, params: {})
      {
        "t" => Protocol::Type::REQUEST, "sid" => sid,
        "resource" => resource, "method" => method, "params" => params
      }
    end

    def response_ok(sid:, value:)
      { "t" => Protocol::Type::RESPONSE, "sid" => sid, "ok" => true, "value" => value }
    end

    def response_error(sid:, code:, message:)
      {
        "t" => Protocol::Type::RESPONSE, "sid" => sid, "ok" => false,
        "error" => { "code" => code, "message" => message }
      }
    end
  end
end
