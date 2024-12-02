# frozen_string_literal: true

module Terminalwire
  class Project
    # We need to worry about the order of paths here because when commands like
    # `rake install` are run, it needs to do it in the order of dependencies since
    # RubyGems hasn't yet built a dependency graph for us.
    GEM_PATHS = %w[
      gem/terminalwire-core
      gem/terminalwire-client
      gem/terminalwire
      gem/terminalwire-server
      gem/terminalwire-rails
    ]

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

    def self.all
      GEM_PATHS.map { |it| new(it) }
    end
  end
end
