# frozen_string_literal: true

require "bundler/gem_helper"
require_relative "support/terminalwire"

Terminalwire::Project.all.each do |project|
  namespace project.task_namespace do
    # Installs gem tasks (build, install, release, etc.)
    project.gem_tasks

    desc "Uninstall #{project.name}"
    task :uninstall do
      sh "gem uninstall #{project.name} --force --executables"
    end

    desc "Test #{project.name}"
    task :spec do
      project.chdir do
        sh "bundle exec rspec spec"
      end
    end
  end
end

# Define global tasks for all gems
%i[build install install:local release uninstall].each do |task|
  desc "#{task.capitalize} all gems"
  task task do
    Terminalwire::Project.all.each do |project|
      project.rake_task(task).invoke
    end
  end
end

namespace :spec do
  desc "Run isolated specs"
  task :isolate do
    Terminalwire::Project.all.each do |project|
      project.rake_task("spec").invoke
    end
  end

  desc "Run integration specs"
  task :integration do
    sh "bundle exec rspec spec"
  end
end

desc "Run specs"
task spec: %i[spec:isolate spec:integration]

# Run specs and build gem.
task default: %i[spec build]
