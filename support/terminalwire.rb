# frozen_string_literal: true

module Terminalwire
  class Project
    attr_reader :dir, :name

    def initialize(dir)
      @dir = dir
      @name = File.basename(dir)
    end

    def chdir
      Dir.chdir(dir) do
        puts "cd #{Dir.pwd}"
        yield
      end
      puts "cd #{Dir.pwd}"
    end

    def gem_tasks
      Bundler::GemHelper.install_tasks(dir:, name:)
    end

    def rake_task(task)
      Rake::Task[rake_task_name(task)]
    end

    def task_namespace
      name.tr("-", "_") # Ensure namespaces are valid Ruby identifiers
    end

    def rake_task_name(*segments)
      segments.prepend(task_namespace).join(":")
    end

    def self.all(glob: "gem/*")
      Dir.glob(glob).select { |it| Dir.exist?(it) }.map { |it| new(it) }
    end
  end
end
