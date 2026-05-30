# frozen_string_literal: true

require_relative "lib/terminalwire2/version"

Gem::Specification.new do |spec|
  spec.name        = "terminalwire2"
  spec.version     = Terminalwire2::VERSION
  spec.authors     = ["Brad Gessler"]
  spec.email       = ["brad@terminalwire.com"]

  spec.summary     = "Terminalwire v2 protocol core + Ruby server runtime"
  spec.description = "Sans-IO implementation of the Terminalwire v2 protocol, plus a server runtime and Thor integration."
  spec.homepage    = "https://terminalwire.com"
  spec.license     = "Nonstandard"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files        = Dir.glob("lib/**/*.rb")
  spec.require_paths = ["lib"]

  spec.add_dependency "msgpack", "~> 1.7"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "thor", "~> 1.3"
end
