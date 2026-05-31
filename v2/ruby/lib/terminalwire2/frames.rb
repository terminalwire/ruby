# frozen_string_literal: true

module Terminalwire2
  # Builders for each frame type. Keep frame construction in one place so the wire
  # shape is defined once. All builders return a Hash with string keys.
  module Frames
    module_function

    def hello(protocol:, capabilities:, program:, entitlement:, terminal: DEFAULT_TERMINAL)
      {
        "t" => Protocol::Type::HELLO, "sid" => Protocol::CONTROL_SID,
        "protocol" => protocol, "capabilities" => capabilities,
        "program" => program, "entitlement" => entitlement,
        "terminal" => terminal
      }
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

    def resize(cols:, rows:)
      { "t" => Protocol::Type::RESIZE, "sid" => Protocol::CONTROL_SID, "cols" => cols, "rows" => rows }
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

    def open(sid:, stream:)
      { "t" => Protocol::Type::OPEN, "sid" => sid, "stream" => stream }
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
