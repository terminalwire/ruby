# frozen_string_literal: true

# terminalwire-rails 2.x IS the v2 Rails integration. A 1.x/0.x app upgrades by
# bumping this gem to "~> 2.0" and redeploying — nothing else changes. Requiring it
# (Bundler does so automatically) loads the v2 server and maps the v1 API names
# (Terminalwire::Thor, Terminalwire::Rails::Thor) onto v2. See lib/terminalwire/rails.rb.
require_relative "../../v2/ruby/lib/terminalwire/v2/version"

Gem::Specification.new do |spec|
  spec.name        = "terminalwire-rails"
  spec.version     = Terminalwire::V2::VERSION
  spec.authors     = ["Brad Gessler"]
  spec.email       = ["brad@terminalwire.com"]

  spec.summary     = "Drop-in Terminalwire v2 integration for Rails"
  spec.description = "Serve a Thor CLI over Terminalwire v2 from a Rails app. Drop-in for the v1 terminalwire-rails: bump to 2.x and redeploy."
  spec.homepage    = "https://terminalwire.com"
  spec.license     = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"]  = "https://github.com/terminalwire/ruby/tree/main/gem/terminalwire-rails"

  spec.files = (
    Dir.glob("{lib,exe,ext,rails}/**/*") + Dir.glob("{README*,LICENSE*}")
  ).select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  # The v2 server engine + the client session / Rails URL helpers it wires up.
  spec.add_dependency "terminalwire", Terminalwire::V2::VERSION
  # MessageEncryptor for the encrypted client session (explicit, even though any
  # Rails app already has it).
  spec.add_dependency "activesupport", ">= 7.1"
  # Reads (and migrates away from) legacy signed-only JWT sessions.
  spec.add_dependency "jwt", ">= 2.0"
  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "rails", "~> 7.2"
end
