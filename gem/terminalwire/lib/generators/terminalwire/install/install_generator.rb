require "bundler"

class Terminalwire::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  argument :binary_name, type: :string, required: true, banner: "binary_name"

  def create_terminal_files
    template "application_terminal.rb.tt", Rails.root.join("app/terminal/application_terminal.rb")
    template "main_terminal.rb", Rails.root.join("app/terminal/main_terminal.rb")
  end

  def create_binary_files
    copy_file "bin/terminalwire", binary_path
    chmod binary_path, 0755, verbose: false
  end

  def add_route
    route <<~ROUTE
      match "/terminal",
        to: Terminalwire::Server::Thor.new(MainTerminal),
        via: [:get, :connect]
    ROUTE
  end

  def print_post_install_message
    say ""
    say "Terminalwire has been successfully installed!", :green
    say "Run `#{binary_path.relative_path_from(Rails.root)}` to verify everything is in working order. For support visit https://terminalwire.com."
    say ""
  end

  private

  def binary_path
    Rails.root.join("bin", binary_name)
  end
end
