# frozen_string_literal: true

core = Gem::Specification.load File.expand_path("../terminalwire-core/terminalwire-core.gemspec", __dir__)

Gem::Specification.new do |spec|
  spec.name = "terminalwire"
  spec.version = core.version
  spec.authors = core.authors
  spec.email = core.email

  spec.summary = core.summary
  spec.description = core.description
  spec.homepage = core.homepage
  # Client (ships the terminalwire-exec executable) — proprietary, not Apache.
  spec.license = "Nonstandard"
  spec.required_ruby_version = core.required_ruby_version

  spec.metadata = core.metadata
  spec.metadata["source_code_uri"] = "https://github.com/terminalwire/ruby/tree/main/#{spec.name}"

  # Specify which files should be added to the gem when it is released.
  spec.files = (
    Dir.glob("{lib,exe,ext}/**/*") + Dir.glob("{README*,LICENSE*}")
  ).select { |f| File.file?(f) }

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = core.require_paths

  # Non-breaking heads-up: the Ruby client is superseded by the v2 client. v1
  # keeps working as-is; upgrade when you can. (Purely informational.)
  spec.post_install_message = <<~MSG
    Terminalwire v2 is here. This v1 Ruby client is superseded by the new
    auto-updating client — install it with:

        curl https://terminalwire.sh | bash

    Your existing v1 setup keeps working for now; please upgrade when you can.
    Details: https://terminalwire.com/docs/client
  MSG

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "terminalwire-client", core.version
end
