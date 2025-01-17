# frozen_string_literal: true

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
  def self.press(path, exe:, to:, ruby_version: "3.3.6")
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
    in /x86_64/
      "amd64"
    in /arm64/
      "arm64"
    end
  end
end

def write(path, *, **, &)
  puts "Writing file to #{path}"
  File.write(path, *, **, &)
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

namespace :tebako do
  build_path = Pathname.new("build")
  stage_path = build_path.join("stage")

  namespace :macos do
    path = stage_path.join("macos/#{Tebako.host_arch}")
    bin_path = path.join("bin/terminalwire-exec")

    task :prepare do
      mkdir_p bin_path.dirname
    end

    task :press do
      sh Tebako.press "gem/terminalwire",
        exe: "terminalwire-exec",
        to: bin_path
    end

    task build: %i[prepare press]
  end

  desc "Build terminal-exec binary for macOS(#{Tebako.host_arch})"
  task macos: "macos:build"

  namespace :ubuntu do
    path = stage_path.join("ubuntu/#{Tebako.host_arch}")
    bin_path = path.join("bin/terminalwire-exec")
    container_path = Pathname.new("/host")
    docker_image = "terminalwire_ubuntu_#{Tebako.host_arch}"

    task :prepare do
      mkdir_p bin_path.dirname
      sh <<~BASH
        docker build https://github.com/bradgessler/tebako-ci-containers.git#macos-qemu \
          -f ubuntu-20.04.Dockerfile \
          -t #{docker_image}
      BASH
    end

    task :press do
      sh <<~BASH
        docker run -v #{File.expand_path(Dir.pwd)}:#{container_path} \
          #{docker_image} \
          bash -c "#{
            Tebako.press "/host/gem/terminalwire",
              exe: "terminalwire-exec",
              to: container_path.join(bin_path)
          }"
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

      path.join("bin/terminalwire").tap do |bin|
        write bin, <<~BASH
          #!/usr/bin/env terminalwire-exec
          url: "wss://terminalwire.com/terminal"
        BASH

        sh "chmod +x #{bin}"
      end

      archive_name = packages_path.join("#{os}-#{arch}.tar.gz")
      sh "tar -czf #{archive_name} -C #{path} ."
    end
  end
end

desc "Build #{Tebako.host_os}(#{Tebako.host_arch}) binary"
task tebako: ["tebako:#{Tebako.host_os}:build", "tebako:package"]

desc "Run specs"
task spec: %i[spec:isolate spec:integration]

# Run specs and build gem.
task default: %i[spec build]
