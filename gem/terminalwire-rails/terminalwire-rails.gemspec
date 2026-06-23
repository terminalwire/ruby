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

  # NOT FOR RELEASE YET — developed in-tree alongside the `terminalwire` gem.
  if $PROGRAM_NAME.end_with?("gem") && ARGV.first&.match?(/\A(build|push|release)\z/)
    raise "terminalwire-rails is not ready to ship — do not build/push this gem yet."
  end

  spec.summary     = "Drop-in Terminalwire v2 integration for Rails"
  spec.description = "Serve a Thor CLI over Terminalwire v2 from a Rails app. Drop-in for the v1 terminalwire-rails: bump to 2.x and redeploy."
  spec.homepage    = "https://terminalwire.com"
  spec.license     = "Nonstandard"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.invalid"
  spec.metadata["source_code_uri"]  = "https://github.com/terminalwire/ruby/tree/main/gem/terminalwire-rails"

  spec.files = (
    Dir.glob("{lib,exe,ext,rails}/**/*") + Dir.glob("{README*,LICENSE*}")
  ).select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  # The v2 server engine + the JWT session / Rails URL helpers it wires up.
  spec.add_dependency "terminalwire", Terminalwire::V2::VERSION
  spec.add_dependency "jwt", ">= 2.0"
  spec.add_dependency "thor", "~> 1.3"

  spec.add_development_dependency "rails", "~> 7.2"
end
