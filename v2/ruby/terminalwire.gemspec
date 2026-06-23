# frozen_string_literal: true

require_relative "lib/terminalwire/v2/version"

Gem::Specification.new do |spec|
  spec.name        = "terminalwire"
  spec.version     = Terminalwire::V2::VERSION
  spec.authors     = ["Brad Gessler"]
  spec.email       = ["brad@terminalwire.com"]

  # NOT FOR RELEASE YET. Developed in-tree; ships as the `terminalwire` gem
  # ("~> 2.0") when the time comes. The guard + invalid push host below keep it
  # from shipping by accident.
  if $PROGRAM_NAME.end_with?("gem") && ARGV.first&.match?(/\A(build|push|release)\z/)
    raise "terminalwire is not ready to ship — do not build/push this gem yet."
  end

  spec.summary     = "Terminalwire v2 protocol core + Ruby server runtime"
  spec.description = "Sans-IO implementation of the Terminalwire v2 protocol, plus a server runtime and Thor integration."
  spec.homepage    = "https://terminalwire.com"
  spec.license     = "Nonstandard"
  spec.required_ruby_version = ">= 3.2.0"

  # Belt-and-suspenders: an invalid push host makes `gem push` fail too.
  spec.metadata["allowed_push_host"] = "https://rubygems.invalid"

  spec.files        = Dir.glob("lib/**/*.rb")
  spec.require_paths = ["lib"]

  spec.add_dependency "msgpack", "~> 1.7"
  # base64 left the Ruby default gems in 3.4; the conformance loader needs it.
  spec.add_dependency "base64", "~> 0.2"
  # JWT-backed client session (Terminalwire::V2::Rails::Session).
  spec.add_dependency "jwt", "~> 2.7"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "thor", "~> 1.3"
end
