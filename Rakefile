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

namespace :tebako do
  namespace :macos do
    %w[amd64 arm64].each do |arch|
      path = Pathname.new("build/macos/#{arch}")
      bin_path = path.join("bin/terminalwire-exec")

      namespace arch do
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

      desc "Build terminal-exec binary for macOS(#{arch})"
      task arch => "#{arch}:build"
    end
  end

  namespace :ubuntu do
    namespace :amd64 do
      path = Pathname.new("build/ubuntu/amd64")
      bin_path = path.join("bin/terminalwire-exec")
      container_path = Pathname.new("/host")
      docker_image = "terminalwire_ubuntu_amd64"

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

    desc "Build terminal-exec binary for Ubuntu(amd64)"
    task amd64: "amd64:build"
  end
end

desc "Run specs"
task spec: %i[spec:isolate spec:integration]

# Run specs and build gem.
task default: %i[spec build]
