module Terminalwire
  module Shells
    # This is used to detect what the user is running for a shell. Terminalwire then
    # then uses this information to determine what files to write to for the root policy.
    #
    class Shell
      attr_reader :name, :login_files, :interactive_files, :logout_files

      def initialize(name)
        @name = name
        @login_files = Set.new
        @interactive_files = Set.new
        @logout_files = Set.new
      end

      class Configuration
        attr_reader :shell

        def initialize(shell, &block)
          @shell = shell
          instance_eval(&block) if block_given?
        end

        def login_file(*paths)
          shell.login_files.merge paths.flatten
        end
        alias :login_files :login_file

        def interactive_file(*paths)
          shell.interactive_files.merge paths.flatten
        end
        alias :interactive_files :interactive_file

        def logout_file(*paths)
          shell.logout_files.merge paths.flatten
        end
        alias :logout_files :logout_file
      end

      def configure(&block)
        Configuration.new(self, &block).shell
      end
    end

    # Encapsulates a collection of shells.
    class Collection
      attr_reader :shells
      include Enumerable

      def initialize
        @shells = []
      end

      def shell(name, &)
        shells << Shell.new(name).configure(&)
      end

      def each(&)
        shells.each(&)
      end

      def login_files
        shells.flat_map { |shell| shell.login_files.to_a }.reject(&:empty?)
      end

      def interactive_files
        shells.flat_map { |shell| shell.interactive_files.to_a }.reject(&:empty?)
      end

      def logout_files
        shells.flat_map { |shell| shell.logout_files.to_a }.reject(&:empty?)
      end

      def names
        shells.map(&:name)
      end

      def find_by_shell(name)
        shells.find { |shell| shell.name == name }
      end

      def find_by_shell_path(path)
        return if path.nil?
        find_by_shell(File.basename(path))
      end

      def files
        login_files + interactive_files + logout_files
      end

      def self.configure(&block)
        Collection.new.tap do |collection|
          collection.instance_eval(&block) if block_given?
        end
      end
    end

    All = Collection.configure do
      shell "bash" do
        login_files %w[~/.bash_profile ~/.bash_login ~/.profile]
        interactive_file "~/.bashrc"
        logout_file "~/.bash_logout"
      end

      shell "zsh" do
        login_files %w[~/.zprofile ~/.zshenv]
        interactive_file "~/.zshrc"
        logout_file "~/.zlogout"
      end

      shell "sh" do
        login_files %w[~/.profile]
      end

      shell "dash" do
        login_files %w[~/.profile]
      end

      shell "fish" do
        interactive_file "~/.config/fish/config.fish"
      end

      shell "ksh" do
        login_files %w[~/.profile]
        interactive_file "~/.kshrc"
      end

      shell "csh" do
        login_files %w[~/.cshrc ~/.login]
        interactive_file "~/.cshrc"
        logout_file "~/.logout"
      end

      shell "tcsh" do
        login_files %w[~/.cshrc ~/.login]
        interactive_file "~/.cshrc"
        logout_file "~/.logout"
      end
    end
  end
end
