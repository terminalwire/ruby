# frozen_string_literal: true

core = Gem::Specification.load File.expand_path("../terminalwire-core/terminalwire-core.gemspec", __dir__)

Gem::Specification.new do |spec|
  spec.name = "terminalwire-rails"
  spec.version = core.version
  spec.authors = core.authors
  spec.email = core.email

  spec.summary = core.summary
  spec.description = core.description
  spec.homepage = core.homepage
  spec.license = core.license
  spec.required_ruby_version = core.required_ruby_version

  spec.metadata = core.metadata
  spec.metadata["source_code_uri"] = "https://github.com/terminalwire/ruby/tree/main/#{spec.name}"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # Specify which files should be added to the gem when it is released.
  spec.files = (
    Dir.glob("{lib,exe,ext,rails}/**/*") + Dir.glob("{README*,LICENSE*}")
  ).select { |f| File.file?(f) }
  spec.require_paths = core.require_paths

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "terminalwire-server", core.version
  spec.add_development_dependency "rails", "~> 7.2"
  spec.add_dependency "jwt", "~> 2.0"
end
