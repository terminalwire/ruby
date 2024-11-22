# frozen_string_literal: true
require "rspec/core/rake_task"

require "rake/clean"
CLOBBER.include "pkg"

require "bundler/gem_helper"
require_relative "support/terminalwire"

Terminalwire::Project.all.each do |project|
  namespace project.task_namespace do
    # Install gem tasks (build, install, release, etc.)
    Bundler::GemHelper.install_tasks(dir: project.gem_dir, name: project.gem_name)

    desc "Uninstall #{project.gem_name}"
    task :uninstall do
      sh "gem uninstall #{project.gem_name} --force --executables"
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
