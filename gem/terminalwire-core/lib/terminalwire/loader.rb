require "zeitwerk"

module Terminalwire
  module Loader
    def self.setup(path = nil)
      path ||= calling_gem_path = caller_locations(1, 1).first.path

      Zeitwerk::Loader.new.tap do |loader|
        loader.tag = File.basename(path, ".rb")
        loader.inflector = Zeitwerk::GemInflector.new(path)
        yield loader if block_given?
        loader.setup
      end
    end

    def self.setup_gem
      calling_gem_path = caller_locations(1, 1).first.path

      setup calling_gem_path do |loader|
        loader.push_dir File.dirname(calling_gem_path), namespace: Terminalwire
        yield loader if block_given?
      end
    end
  end
end
