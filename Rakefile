# frozen_string_literal: true

require "bundler/setup"
require "bundler/gem_helper"
require_relative "support/terminalwire"

Terminalwire::Project.all.each do |project|
  namespace project.task_namespace do
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

module Tebako
  RUBY_VERSION = "3.3.6"

  def self.press(path, exe:, to:, ruby_version: RUBY_VERSION)
    "tebako press -r #{path} -e #{exe} -R #{ruby_version} -o #{to}"
  end

  def self.host_os
    case RbConfig::CONFIG["host_os"]
    in /darwin/
      "macos"
    in /linux/
      "ubuntu"
    end
  end

  def self.host_arch
    case RbConfig::CONFIG["host_cpu"]
    when /x86_64/
      "amd64"
    when /arm64/, /aarch64/
      "arm64"
    else
      raise "Unsupported architecture: #{RbConfig::CONFIG["host_cpu"]}"
    end
  end
end

def write(path, *, **, &)
  puts "Writing file to #{path}"
  File.write(path, *, **, &)
end

namespace :gem do
  # Define global tasks for all gems
  %i[build install install:local release uninstall].each do |task|
    desc "#{task.capitalize} all gems"
    task task do
      Terminalwire::Project.all.each do |project|
        project.rake_task(task).invoke
      end
    end
  end
end

desc "Build gem"
task :gem, %i[gem:build gem:install]

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

namespace :tebako do
  build_path = Pathname.new("build")
  stage_path = build_path.join("stage")

  namespace :build do
    path = stage_path.join("#{Tebako.host_os}/#{Tebako.host_arch}")
    bin_path = path.join("bin/terminalwire-exec")

    task :prepare do
      mkdir_p bin_path.dirname
    end

    task :press do
      Bundler.with_unbundled_env do
        sh Tebako.press "gem/terminalwire",
          exe: "terminalwire-exec",
          to: bin_path
      end
    end
  end
  desc "Build terminal-exec binary for #{Tebako.host_os}(#{Tebako.host_arch})"
  task build: %w[build:prepare build:press]

  namespace :ubuntu do
    docker_image = "terminalwire-ubuntu-tebako-#{Tebako.host_arch}"

    task :prepare do
      sh <<~BASH
        docker build \
          ./containers/ubuntu-tebako \
          -t #{docker_image}
      BASH
    end

    task :press do
      sh <<~BASH
        docker run -v #{File.expand_path(Dir.pwd)}:/host \
          -w /host \
          #{docker_image} \
          bash -c "bundle && bin/rake tebako"
      BASH
    end

    task build: %i[prepare press]
  end

  desc "Build terminal-exec binary for Ubuntu"
  task ubuntu: "ubuntu:build"

  task :package do
    packages_path = build_path.join("packages")
    sh "mkdir -p #{packages_path}"

    Dir.glob(stage_path.join("*/*")).map{ Pathname.new(_1) }.each do |path|
      path.each_filename.to_a => *_, os, arch

      write path.join("VERSION"),
        Terminalwire::VERSION

      Terminalwire::Binary.new(
        url: "wss://terminalwire.com/terminal"
      ).write path.join("bin/terminalwire")

      archive_name = packages_path.join("#{os}-#{arch}.tar.gz")
      sh "tar -czf #{archive_name} -C #{path} ."
    end
  end
end

desc "Build #{Tebako.host_os}(#{Tebako.host_arch}) binary"
task tebako: %i[tebako:build tebako:package]

desc "Run specs"
task spec: %i[spec:isolate spec:integration]

# Run tests and build everything.
task default: %i[spec gem tebako]
