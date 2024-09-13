# frozen_string_literal: true

require_relative "lib/terminalwire/version"

Gem::Specification.new do |spec|
  spec.name = "terminalwire"
  spec.version = Terminalwire::VERSION
  spec.authors = ["Brad Gessler"]
  spec.email = ["brad@terminalwire.com"]

  spec.summary = "Ship a CLI for your web app. No API required."
  spec.description = "Stream command-line apps from your server without a web API"
  spec.homepage = "https://terminalwire.com/ruby"
  spec.license = "Proprietary"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/terminalwire/ruby"
  spec.metadata["changelog_uri"] = "https://github.com/terminalwire/ruby/tags"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "async-websocket", "~> 0.25"
  spec.add_dependency "zeitwerk", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "msgpack", "~> 1.7"
  spec.add_dependency "launchy", "~> 3.0"
  spec.add_dependency "jwt", "~> 2.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rails", "~> 7.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
