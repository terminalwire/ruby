# frozen_string_literal: true

require "yaml"
require "base64"
require "pathname"

module Terminalwire::V2
  # Loads the language-neutral conformance corpus and resolves its typed
  # sentinels ($bin, bytes_hex) into native Ruby values. The Go runner does the
  # equivalent. This is what lets one corpus validate every implementation.
  module Conformance
    module_function

    def root
      Pathname.new(ENV.fetch("TERMINALWIRE_CORPUS") do
        File.expand_path("../../../conformance", __dir__)
      end)
    end

    def vectors_dir
      root.join("vectors")
    end

    # Load every .yml file in a category (e.g. "negotiate") and return a flat
    # array of cases with $bin sentinels resolved to binary strings.
    def load(category)
      Dir.glob(vectors_dir.join(category, "*.yml")).sort.flat_map do |path|
        data = YAML.safe_load_file(path)
        resolve(data)
      end
    end

    # Recursively resolve { "$bin" => base64 } sentinels into binary strings.
    def resolve(value)
      case value
      when Hash
        if value.size == 1 && value.key?("$bin")
          Base64.decode64(value.fetch("$bin")).b
        else
          value.transform_values { |v| resolve(v) }
        end
      when Array
        value.map { |v| resolve(v) }
      else
        value
      end
    end

    # "a1 74 ff" -> binary string
    def hex_to_bytes(hex)
      hex.split.map { |byte| Integer(byte, 16) }.pack("C*")
    end
  end
end
