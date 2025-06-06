# frozen_string_literal: true

require_relative "lib/terminalwire/version"

Gem::Specification.new do |spec|
  spec.name = "terminalwire-core"
  spec.version = Terminalwire::VERSION
  spec.authors = ["Brad Gessler"]
  spec.email = ["brad@terminalwire.com"]

  spec.summary = "Ship a CLI for your web app. No API required."
  spec.description = "Stream command-line apps from your server without a web API"
  spec.homepage = "https://terminalwire.com/ruby"
  spec.license = "AGPL"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/terminalwire/ruby"
  spec.metadata["changelog_uri"] = "https://github.com/terminalwire/ruby/tags"
  spec.metadata["funding_uri"] = "https://terminalwire.com/funding"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # Specify which files should be added to the gem when it is released.
  spec.files = (
    Dir.glob("{lib,exe,ext}/**/*") + Dir.glob("{README*,LICENSE*}")
  ).select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "async-websocket", "~> 0.30"
  spec.add_dependency "zeitwerk", "~> 2.0"
  spec.add_dependency "msgpack", "~> 1.7"
  spec.add_dependency "uri-builder", "~> 0.1.9"
  spec.add_dependency "base64", "~> 0.2.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
