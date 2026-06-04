# frozen_string_literal: true
#
# A one-page Rails app that serves a Thor CLI over Terminalwire (v2).
#
# Boot it, then drive it from your own terminal with the Terminalwire client:
#
#     puma examples/v2/rails_thor_demo/config.ru -p 3000
#     terminalwire-connect ws://localhost:3000/terminal hello
#     terminalwire-connect ws://localhost:3000/terminal           # the welcome banner
#     terminalwire-connect ws://localhost:3000/terminal table
#     terminalwire-connect ws://localhost:3000/terminal survey
#     terminalwire-connect ws://localhost:3000/terminal login
#     terminalwire-connect ws://localhost:3000/terminal whoami
#
# The whole story in one file:
#   1. an ordinary Thor CLI that `include`s Terminalwire::V2::Server::Thor — its
#      puts/ask/yes?/say and any tty-* / pastel output land on YOUR terminal;
#   2. a Rails::Application that mounts Terminalwire::V2::Server::Rack at /terminal.
#      That one line is the entire integration — the WebSocket upgrade, the Rack 3
#      streaming, and the per-connection threading all live inside the gem.

require "logger"

# --- load the (unreleased) v2 server library straight from the repo -----------
V2_LIB = File.expand_path("../../../v2/ruby/lib", __dir__)
$LOAD_PATH.unshift(V2_LIB) unless $LOAD_PATH.include?(V2_LIB)

require "terminalwire/v2"
require "terminalwire/v2/server/thor" # the Thor integration (opt-in; pulls in thor)
require "terminalwire/v2/server/rack" # the WebSocket Rack endpoint (opt-in; async-websocket)

# Install Terminalwire's stream routing BEFORE loading the TTY libs. Some (tty-color,
# which Pastel uses) snapshot $stdout/$stderr at load time; installing first means
# they capture the router, so under #render they detect the CLIENT's color + size.
Terminalwire::V2::Server.install!

# TTY ecosystem — dropped in unmodified. Under #render (Server.redirect) their own
# APIs (Pastel.new, TTY::Screen.width) auto-detect the CLIENT terminal over the wire.
require "pastel"
require "tty-screen"
require "tty-table"
require "tty-box"
require "tty-tree"
require "tty-progressbar"
require "tty-spinner"
require "tty-markdown"
require "tty-font"

require "rails"
require "action_controller/railtie"

# ------------------------------------------------------------------------------
# 1. The CLI. This is just Thor. The single `include` is what reroutes all of its
#    I/O through the connected client instead of the server's $stdout/$stdin.
# ------------------------------------------------------------------------------
class DemoCLI < Thor
  include Terminalwire::V2::Server::Thor

  def self.exit_on_failure? = true

  desc "hello [NAME]", "Greet you by name (asks if you don't say)"
  def hello(name = nil)
    name ||= ask("What's your name?")
    pastel = Pastel.new(enabled: context.terminal.color?)
    puts pastel.green.bold("Hello, #{name}!") + " 👋"
    puts "This CLI is running on a Rails server, drawing on " +
         pastel.cyan("your terminal") +
         " (#{context.terminal.cols}×#{context.terminal.rows})."
    puts pastel.dim("Try: table · survey · login · whoami · sysinfo")
  end
  default_command :hello

  desc "table", "tty-table, dropped in — auto-colors via Pastel, no special args"
  def table
    render do
      pastel = Pastel.new # auto-detects color from $stdout (the client) under #render
      rows = [
        ["stdout/stderr", "streaming", pastel.green("✓")],
        ["ask / yes? / password", "interactive", pastel.green("✓")],
        ["file + directory", "sandboxed to your origin", pastel.green("✓")],
        ["terminal size / color", "live", pastel.green("✓")],
        ["tty-table / pastel", "server-side TUI libs", pastel.green("✓")],
      ]
      $stdout.puts TTY::Table.new(header: %w[Capability Notes Works], rows: rows).render(:unicode, padding: [0, 1])
    end
  end

  desc "survey", "Show off interactive prompts (ask, yes?, password)"
  def survey
    name = ask("Name?")
    color = ask("Favorite color?", default: "blue")
    ok = yes?("Ship it? [y/N]")
    secret = ask("Make up a passphrase (hidden):", echo: false)
    puts
    puts "name=#{name.inspect} color=#{color.inspect} ship=#{ok} passphrase=#{secret.to_s.length} chars"
  end

  desc "sysinfo", "What the server can see about your terminal + environment"
  def sysinfo
    t = context.terminal
    puts "terminal : #{t.cols}×#{t.rows}  term=#{t.term}  color=#{t.color}  tty=#{t.stdout.tty?}"
    puts "HOME     : #{context.env('HOME')}"          # a granted env var
    puts "authority: #{context.entitlement&.dig('authority')}"
    puts "sandbox  : #{context.storage_path}"
  end

  desc "login", "Persist a session token into your origin's sandbox (a real file)"
  def login
    path = session_file or return
    token = "tok_#{Time.now.to_i.to_s(36)}#{rand(36**6).to_s(36)}"
    context.file.write(path, token)
    puts "Wrote a session token to #{path} on your machine."
    puts "It lives only under this server's origin folder. Run `whoami`, then `logout`."
  end

  desc "whoami", "Read the session token back from your machine"
  def whoami
    path = session_file or return
    if context.file.exist?(path)
      puts "Logged in. token=#{context.file.read(path)}"
    else
      puts "Not logged in. Run `login` first."
    end
  end

  desc "logout", "Delete the session token from your machine"
  def logout
    path = session_file or return
    if context.file.exist?(path)
      context.file.delete(path)
      puts "Logged out — token deleted."
    else
      puts "Nothing to delete."
    end
  end

  # ----------------------------------------------------------------------------
  # TTY showcase — spot-check rich terminal output rendered server-side and drawn
  # on YOUR terminal. Each wraps the body in #render so $stdout points at the
  # client and the TTY libs auto-detect its color + width.
  # ----------------------------------------------------------------------------

  desc "colors", "Pastel palette: foreground, background, and styles"
  def colors
    render do
      p = Pastel.new
      $stdout.puts p.bold("Foreground:")
      $stdout.puts %i[black red green yellow blue magenta cyan white].map { |c| p.decorate("  #{c} ", c) }.join
      $stdout.puts %i[bright_red bright_green bright_yellow bright_blue bright_magenta bright_cyan].map { |c| p.decorate(" #{c} ", c) }.join
      $stdout.puts p.bold("\nBackgrounds:")
      $stdout.puts %i[on_red on_green on_yellow on_blue on_magenta on_cyan].map { |c| p.decorate("  #{c}  ", c, :black) }.join
      $stdout.puts p.bold("\nStyles:")
      $stdout.puts [p.bold("bold"), p.dim("dim"), p.italic("italic"), p.underline("underline"), p.inverse("inverse"), p.strikethrough("strike")].join("  ")
    end
  end

  desc "box [TEXT]", "tty-box, dropped in — TTY::Screen.width is your terminal"
  def box(text = "Terminalwire renders this box server-side; it's drawn on your terminal.")
    render do
      $stdout.puts TTY::Box.frame(
        text,
        width: TTY::Screen.width, padding: 1, align: :center,
        title: { top_left: " 📦 box ", bottom_right: " #{TTY::Screen.width}cols " },
        style: { border: { fg: :cyan } }
      )
    end
  end

  desc "tree", "A tty-tree of a nested structure"
  def tree
    render do
      data = { "terminalwire" => [
        { "client (Go)" => ["transport", "entitlement", "frontend"] },
        { "server" => [{ "ruby" => ["puma", "falcon"] }, "elixir"] },
        "protocol + conformance",
      ] }
      $stdout.puts TTY::Tree.new(data).render
    end
  end

  desc "markdown", "Render Markdown (headings, list, code, table) with tty-markdown"
  def markdown
    doc = <<~MD
      # Terminalwire
      Ship a **CLI** from your web app — the server drives _your_ terminal.

      - streaming output
      - interactive prompts
      - `tty-*` widgets

      ```ruby
      class CLI < Thor
        include Terminalwire::V2::Server::Thor
      end
      ```

      | Server | Transport |
      |--------|-----------|
      | Ruby   | Puma / Falcon |
      | Elixir | Bandit |
    MD
    render { $stdout.puts TTY::Markdown.parse(doc) } # tty-markdown auto-sizes via TTY::Screen
  end

  desc "bigtext [TEXT]", "Big ASCII-art text (tty-font)"
  def bigtext(text = "WIRE")
    render { $stdout.puts Pastel.new.cyan(TTY::Font.new(:standard).write(text)) }
  end

  desc "progress", "An animated progress bar streaming to your terminal"
  def progress
    render do
      bar = TTY::ProgressBar.new("downloading [:bar] :percent :eta", total: 40, width: 30, output: $stdout)
      40.times { sleep 0.04; bar.advance }
      bar.finish
      $stdout.puts "done."
    end
  end

  desc "spinner", "An animated spinner (manual frames over the wire)"
  def spinner
    render do
      spin = TTY::Spinner.new("[:spinner] crunching numbers…", format: :dots, output: $stdout)
      30.times { spin.spin; sleep 0.05 }
      spin.success(Pastel.new.green("(done)"))
    end
  end

  desc "resize", "Draw a frame sized to your terminal; resize to watch it reflow (Enter quits)"
  def resize
    draw = lambda do
      t = context.terminal
      frame = TTY::Box.frame(
        "Resize your terminal — this frame redraws to fit.\n\n" \
        "cols=#{t.cols}  rows=#{t.rows}  term=#{t.term}",
        width: [t.cols, 24].max, height: [t.rows - 1, 6].max, align: :center, padding: 1,
        title: { top_left: " terminalwire ", bottom_right: " Enter to quit " }
      )
      context.print("\e[2J\e[H#{frame}") # clear + home, then the frame
    end
    context.on_resize { draw.call }      # fires on resize (SIGWINCH from the client)
    draw.call
    gets                                 # block until Enter; resizes redraw meanwhile
  ensure
    context.print("\e[2J\e[H")
  end

  desc "menu", "Single-keypress menu (cbreak mode — no Enter needed)"
  def menu
    puts "Pick one — press a key: [r]uby  [e]lixir  [g]o  [q]uit"
    key = context.read_key
    label = { "r" => "Ruby", "e" => "Elixir", "g" => "Go", "q" => "(quit)" }[key.to_s.downcase] || "unknown (#{key.inspect})"
    puts "You pressed #{key.inspect} → #{label}"
  end

  no_commands do
    # Run a block with the client's terminal as $stdout/$stderr (fiber-locally),
    # so Pastel/tty-* auto-detect the client's color + size. The clean way to run
    # ordinary terminal libraries server-side. (Resize redraws can't use this —
    # they fire on the pump thread — so #resize writes via the context directly.)
    def render(&block)
      Terminalwire::V2::Server.redirect(context) { |**| block.call }
    end

    # The client sandbox we may write to (its ~/.terminalwire/authorities/<origin>/
    # folder), reported in the entitlement. nil if the client granted nothing.
    def session_file
      dir = context.storage_path
      return (warn("This client didn't grant a writable directory.") && nil) unless dir
      "#{dir}/session.json"
    end
  end
end

# ------------------------------------------------------------------------------
# 2. The Rails app. Mounting the endpoint is the whole integration — one line.
#    Terminalwire::V2::Server::Rack speaks the Rack 3 streaming protocol, so it
#    runs on Puma and Falcon, and it owns all the per-connection threading/bridging
#    internally so this app never has to think about it.
# ------------------------------------------------------------------------------
WELCOME_HTML = <<~HTML
  <!doctype html><meta charset=utf-8><title>Terminalwire demo</title>
  <body style="font:16px/1.5 ui-monospace,monospace;max-width:42rem;margin:4rem auto;padding:0 1rem">
  <h1>🚀 Terminalwire Thor demo</h1>
  <p>This Rails app serves a Thor CLI over a WebSocket. Drive it from your terminal:</p>
  <pre style="background:#111;color:#eee;padding:1rem;border-radius:8px">terminalwire-connect ws://localhost:3000/terminal hello
  terminalwire-connect ws://localhost:3000/terminal table
  terminalwire-connect ws://localhost:3000/terminal survey
  terminalwire-connect ws://localhost:3000/terminal login</pre>
  </body>
HTML

class Demo < Rails::Application
  config.load_defaults 8.0
  config.eager_load = false
  config.consider_all_requests_local = true
  config.secret_key_base = "terminalwire-demo-not-a-real-secret-0000000000000000"
  config.logger = Logger.new($stdout)
  config.hosts.clear # local demo; accept any Host header

  routes.append do
    mount Terminalwire::V2::Server::Rack.new(DemoCLI, verbose: true), at: "/terminal"
    root to: ->(_env) { [200, { "content-type" => "text/html" }, [WELCOME_HTML]] }
  end
end

Demo.initialize!
