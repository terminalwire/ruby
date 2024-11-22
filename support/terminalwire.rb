# frozen_string_literal: true

module Terminalwire
  class Project
    attr_reader :gem_dir, :gem_name

    def initialize(gem_dir)
      @gem_dir = gem_dir
      @gem_name = File.basename(gem_dir)
    end

    def task_namespace
      gem_name.tr("-", "_") # Ensure namespaces are valid Ruby identifiers
    end

    def chdir(&block)
      Dir.chdir(gem_dir, &block)
    end

    def self.all
      Dir.glob("gem/*").select { |it| Dir.exist?(it) }.map { |it| new(it) }
    end
  end
end
