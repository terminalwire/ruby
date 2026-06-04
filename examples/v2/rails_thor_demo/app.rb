# frozen_string_literal: true
#
# A one-page Rails app that serves a Thor CLI over Terminalwire (v2).
#
# Boot it, then drive it from your own terminal with the Terminalwire client:
#
#     puma examples/v2/rails_thor_demo/config.ru -p 3000
#     /tmp/terminalwire ws://localhost:3000/terminal hello
#     /tmp/terminalwire ws://localhost:3000/terminal           # the welcome banner
#     /tmp/terminalwire ws://localhost:3000/terminal table
#     /tmp/terminalwire ws://localhost:3000/terminal survey
#     /tmp/terminalwire ws://localhost:3000/terminal login
#     /tmp/terminalwire ws://localhost:3000/terminal whoami
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
require "pastel"
require "tty-table"

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

  desc "table", "Render a tty-table sized to your terminal"
  def table
    pastel = Pastel.new(enabled: context.terminal.color?)
    rows = [
      ["stdout/stderr", "streaming", pastel.green("✓")],
      ["ask / yes? / password", "interactive", pastel.green("✓")],
      ["file + directory", "sandboxed to your origin", pastel.green("✓")],
      ["terminal size / color", "live", pastel.green("✓")],
      ["tty-table / pastel", "server-side TUI libs", pastel.green("✓")],
    ]
    table = TTY::Table.new(header: %w[Capability Notes Works], rows: rows)
    # Render against the *client's* width, not the server's.
    puts table.render(:unicode, resize: true, width: [context.terminal.cols, 80].min,
                                padding: [0, 1])
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

  no_commands do
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
  <pre style="background:#111;color:#eee;padding:1rem;border-radius:8px">terminalwire ws://localhost:3000/terminal hello
  terminalwire ws://localhost:3000/terminal table
  terminalwire ws://localhost:3000/terminal survey
  terminalwire ws://localhost:3000/terminal login</pre>
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
