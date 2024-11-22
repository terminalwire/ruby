# frozen_string_literal: true

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

    desc "Run specs for #{project.gem_name}"
    task :spec do
      failed_projects = []

      puts "Running specs for #{project.gem_name}..."
      project.chdir do
        sh "bundle exec rspec" do |ok, res|
          unless ok
            failed_projects << project.gem_name
            puts res
          end
        end
      end

      fail "#{failed_projects.map(&:inspect).join(", ")} suites failed" if failed_projects.any?
    end
  end
end

# Define global tasks for all gems
%w[build install install:local release spec uninstall].each do |task|
  desc "#{task.capitalize} all gems"
  task task do
    Terminalwire::Project.all.each do |project|
      Rake::Task["#{project.task_namespace}:#{task}"].invoke
    end
  end
end

desc "Run benchmarks"
task :benchmark do
  Dir["./benchmarks/**_benchmark.rb"].each do |benchmark|
    sh "ruby #{benchmark}"
  end
end

desc "Run CI tasks"
task ci: %w[spec benchmark]

task :default => :spec
