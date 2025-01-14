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

module Tebako
  class Docker
    def initialize(image:, platform:)
      @image = image
      @platform = platform
    end

    def press(path, to:, **)
      host_to, host_file = File.split(to)

      <<~BASH
        docker run --platform #{@platform} \
          -v #{File.expand_path(path)}:/build/in \
          -v #{File.expand_path(host_to)}:/build/out \
          -t ghcr.io/tamatebako/tebako-#{@image}:latest \
          bash -c "#{Tebako.press("/build/in", to: File.join("/build/out", host_file), **)}"
      BASH
    end
  end

  def self.press(path, exe:, to:, ruby_version: "3.3.6")
    "tebako press -r #{path} -e #{exe} -R #{ruby_version} -o #{to}"
  end

  def self.press_alpine_amd64(...)
    Docker.new(
      image: "alpine-3.17",
      platform: "linux/amd64"
    ).press(...)
  end

  def self.press_ubuntu_amd64(...)
    Docker.new(
      image: "ubuntu-20.04",
      platform: "linux/amd64"
    ).press(...)
  end
end

def with_env(**env)
  original = ENV.to_hash # Save the original ENV
  ENV.merge! env.transform_keys(&:to_s) # Set the temporary ENV vars
  yield # Execute the block
ensure
  ENV.replace original # Restore the original ENV
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

      task :prepare do
        mkdir_p bin_path.dirname
      end

      task :press do
        with_env "DOCKER_HOST": "ssh://brad@home-server.local" do
          sh Tebako.press_ubuntu_amd64 "gem/terminalwire",
            exe: "terminalwire-exec",
            to: bin_path
        end
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


__END__

# def env
#   Hash.new.tap do |env|
#     env["LG_VADDR"] = lg_vaddr if lg_vaddr
#   end
# end

# def env_flags
#   env.map { |k,v| "-e #{k}=#{v}" }.join(" ")
# end

# private

# def lg_vaddr
#   operating_system = `uname -s`.chomp
#   architecture = `uname -m`.chomp

#   emulated = `sysctl -n sysctl.proc_translated`.chomp == "1"
#   macos = operating_system == "Darwin"

#   if macos
#     if (architecture == "x86_64" and emulated) or architecture == "arm64"
#       "39"
#     elsif architecture == "x86_64"
#       "48"
#     end
#   end
# end

---


# class BuildTargets
#   attr_reader :architectures
#   alias :archs :architectures

#   class Architecture
#     attr_reader :name, :operating_systems

#     def initialize(name:)
#       @name = name
#       @operating_systems = []
#     end

#     def operating_system(name,**, &)
#       @operating_systems << OperatingSystem.new(name:, architecture: self, **).tap do |os|
#         yield os if block_given?
#       end
#     end
#     alias :os :operating_system
#   end

#   class OperatingSystem < Data.define(:name, :architecture)
#     def build_path
#       Pathname.new("#{architecture.name}-#{name}")
#     end
#   end

#   def initialize
#     @architectures = []
#   end

#   def architecture (name, **, &)
#     @architectures << Architecture.new(name:,**).tap(&)
#   end
#   alias :arch :architecture

#   def operating_systems
#     @architectures.flat_map(&:operating_systems)
#   end

#   def self.configure(*,**, &)
#     new(*,**).tap(&)
#   end
# end

# namespace :package do
#   ARCHICTECTURES = %w[amd64 arm64]
#   OPERATING_SYSTEMS = %w[ubuntu macos]

#   target = BuildTargets.configure do |targets|
#     targets.arch "amd64" do |it|
#       it.os "ubuntu"
#       it.os "macos"
#     end
#     targets.arch "arm64" do |it|
#       it.os "ubuntu"
#       it.os "macos"
#     end
#   end

#   target.archs.each do |arch|
#     namespace arch.name do
#       arch.operating_systems.each do |os|
#         namespace os.name do
#           desc "Build terminal-exec binary for #{arch.name} #{os.name}"
#           task :build do
#             sh "tebako press -r gem/terminalwire -e terminalwire-exec -o build/bin/terminalwire-exec"
#           end
#         end
#       end
#     end
#   end
# end
#
