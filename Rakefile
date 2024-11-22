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
  end
end

# Define global tasks for all gems
%i[build install install:local release uninstall].each do |task|
  desc "#{task.capitalize} all gems"
  task task do
    Terminalwire::Project.all.each do |project|
      Rake::Task["#{project.task_namespace}:#{task}"].invoke
    end
  end
end

desc "Run all specs"
task :spec do
  sh "bundle exec rspec spec"
end

desc "Run CI tasks"
task ci: %i[spec build]
