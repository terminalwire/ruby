# frozen_string_literal: true

module Terminalwire
  class Project
    attr_reader :dir, :name

    def initialize(dir)
      @dir = dir
      @name = File.basename(dir)
    end

    def task_namespace
      name.tr("-", "_") # Ensure namespaces are valid Ruby identifiers
    end

    def chdir(&block)
      Dir.chdir(dir, &block)
    end

    def gem_tasks
      Bundler::GemHelper.install_tasks(dir:, name:)
    end

    def self.all
      Dir.glob("gem/*").select { |it| Dir.exist?(it) }.map { |it| new(it) }
    end
  end
end
