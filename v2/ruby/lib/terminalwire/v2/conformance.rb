# frozen_string_literal: true

require "yaml"
require "json"
require "base64"
require "pathname"

module Terminalwire::V2
  # Loads the language-neutral conformance corpus and resolves its typed sentinels
  # into native Ruby values. The Go and Elixir runners do the equivalent. This is
  # what lets one corpus validate every implementation.
  #
  # Two file shapes live in the corpus:
  #   * simple vector tables (negotiate/roundtrip/golden/validate/flow) — YAML/JSON,
  #     with `$bin` base64 + `bytes_hex` sentinels;
  #   * "tapes" (session) — S-expressions (see Sexp): recorded client<->server
  #     interactions. Sexp is used for the tapes because it is trivial and
  #     unambiguous to parse in every language and reads like a transcript.
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

    # Load every vector file in a category, dispatching by extension, and return a
    # flat array of cases with sentinels resolved to native values. Fails LOUDLY
    # when the corpus is absent rather than silently running zero cases.
    def load(category)
      unless vectors_dir.directory?
        raise "conformance corpus not found at #{vectors_dir} — set TERMINALWIRE_CORPUS " \
              "to the corpus directory (it ships in terminalwire/protocol). Without it " \
              "the corpus specs would silently run zero cases."
      end
      Dir.glob(vectors_dir.join(category, "*.{yml,yaml,json,sexp}")).sort.flat_map do |path|
        case File.extname(path)
        when ".sexp" then Sexp.load(File.read(path))      # tapes (bin already resolved)
        when ".json" then resolve(JSON.parse(File.read(path)))
        else resolve(YAML.safe_load_file(path))
        end
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

    # A tiny S-expression reader + tape interpreter. The whole grammar:
    #   list = "(" form* ")" ;  atom = token | "string" | :keyword | number | true|false|nil ; ; comment
    # Data mapping (unambiguous by each list's shape):
    #   (type :k v ...) FRAME -> {"t"=>type, k=>v}   (:k v ...) MAP -> {k=>v}
    #   (a b c) LIST -> [a,b,c]                       (bin "b64") -> bytes
    # A tape file is (tape NAME (ROLE ...config) <transcript>...). The transcript is
    # flat and reads like a recording; #interpret groups it into the step shape the
    # runners consume ({recv|do, emit:[...], reject} / {process, out:[...], exit, stdout}).
    module Sexp
      module_function

      def load(text)
        read_all(text).map { |form| interpret(form) }
      end

      def read_all(text)
        toks = tokenize(text)
        forms = []
        forms << read_form(toks) until toks.empty?
        forms
      end

      def tokenize(str)
        toks = []
        i = 0
        n = str.length
        while i < n
          c = str[i]
          if c == ";"
            i += 1 while i < n && str[i] != "\n"
          elsif c =~ /\s/
            i += 1
          elsif c == "(" || c == ")"
            toks << c
            i += 1
          elsif c == '"'
            j = i + 1
            buf = +""
            while j < n && str[j] != '"'
              if str[j] == "\\"
                buf << { "n" => "\n", "t" => "\t", "r" => "\r" }.fetch(str[j + 1], str[j + 1])
                j += 2
              else
                buf << str[j]
                j += 1
              end
            end
            toks << [:str, buf]
            i = j + 1
          else
            j = i
            j += 1 while j < n && !"() \t\r\n;\"".include?(str[j])
            toks << [:tok, str[i...j]]
            i = j
          end
        end
        toks
      end

      def read_form(toks)
        t = toks.shift
        if t == "("
          list = []
          list << read_form(toks) until toks.first == ")"
          toks.shift
          list
        elsif t.is_a?(Array) && t[0] == :str
          t[1]
        else
          atom(t[1])
        end
      end

      def atom(text)
        case text
        when "true" then true
        when "false" then false
        when "nil" then nil
        else
          if text.start_with?(":") then text[1..].to_sym
          elsif text.match?(/\A-?\d+\z/) then text.to_i
          elsif text.match?(/\A-?\d+\.\d+\z/) then text.to_f
          else text
          end
        end
      end

      def value(form)
        return form unless form.is_a?(Array)
        return [] if form.empty?

        head = form[0]
        if head.is_a?(Symbol)
          to_map(form)
        elsif head == "bin"
          Base64.decode64(form[1]).b
        elsif form[1..].any? { |e| e.is_a?(Symbol) }
          { "t" => head }.merge(to_map(form[1..]))
        else
          form.map { |e| value(e) }
        end
      end

      def to_map(pairs)
        h = {}
        pairs.each_slice(2) { |k, v| h[k.to_s] = value(v) }
        h
      end

      def interpret(form)
        _tape, name, config_form, *transcript = form
        role = config_form[0]
        config = to_map(config_form[1..])
        steps = role == "client" ? group_client(transcript) : group_server(transcript)
        { "name" => name, "role" => role, "config" => config, "tape" => steps }
      end

      def group_server(forms)
        steps = []
        forms.each do |f|
          case f[0]
          when "recv" then steps << { "recv" => value(f[1]), "emit" => [] }
          when "do" then steps << { "do" => action(f[1]), "emit" => [] }
          when "send" then steps.last["emit"] << { "send" => value(f[1]) }
          when "event"
            ev = { "event" => f[1].to_s }
            ev["data"] = to_map(f[2..]) unless f[2..].empty?
            steps.last["emit"] << ev
          when "reject" then steps.last["reject"] = true
          end
        end
        steps
      end

      def group_client(forms)
        steps = []
        forms.each do |f|
          case f[0]
          when "process" then steps << { "process" => value(f[1]), "out" => [] }
          when "out" then steps.last["out"] << value(f[1])
          when "exit" then steps.last["exit"] = f[1]
          when "stdout" then steps.last["stdout"] = f[1]
          end
        end
        steps
      end

      def action(form)
        head = form[0]
        rest = form[1..]
        if rest.length == 1 && !rest[0].is_a?(Symbol) && !rest[0].is_a?(Array)
          { head => rest[0] }
        else
          { head => to_map(rest) }
        end
      end
    end
  end
end
