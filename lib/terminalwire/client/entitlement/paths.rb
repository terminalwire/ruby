module Terminalwire::Client::Entitlement
  # A list of paths and permissions that server has to write on the client workstation.
  class Paths
    class Permit
      attr_reader :path, :mode
      # Ensure the default file mode is read/write for owner only. This ensures
      # that if the server tries uploading an executable file, it won't be when it
      # lands on the client.
      #
      # Eventually we'll move this into entitlements so the client can set maximum
      # permissions for files and directories.
      MODE = 0o600 # rw-------

      # Constants for permission bit masks
      OWNER_PERMISSIONS = 0o700 # rwx------
      GROUP_PERMISSIONS = 0o070 # ---rwx---
      OTHERS_PERMISSIONS = 0o007 # ------rwx

      # We'll validate that modes are within this range.
      MODE_RANGE = 0o000..0o777

      def initialize(path:, mode: MODE)
        @path = Pathname.new(path).expand_path
        @mode = convert(mode)
      end

      def permitted_path?(path)
        # This MUST be done via File.fnmatch because Pathname#fnmatch does not work. If you
        # try changing this 🚨 YOU MAY CIRCUMVENT THE SECURITY MEASURES IN PLACE. 🚨
        File.fnmatch @path.to_s, File.expand_path(path), File::FNM_PATHNAME
      end

      def permitted_mode?(value)
        # Ensure the mode is at least as permissive as the permitted mode.
        mode = convert(value)

        # Extract permission bits for owner, group, and others
        owner_bits = mode & OWNER_PERMISSIONS
        group_bits = mode & GROUP_PERMISSIONS
        others_bits = mode & OTHERS_PERMISSIONS

        # Ensure that the mode doesn't grant more permissions than @mode in any class (owner, group, others)
        (owner_bits <= @mode & OWNER_PERMISSIONS) &&
        (group_bits <= @mode & GROUP_PERMISSIONS) &&
        (others_bits <= @mode & OTHERS_PERMISSIONS)
      end

      def permitted?(path:, mode: @mode)
        permitted_path?(path) && permitted_mode?(mode)
      end

      def serialize
        {
          location: @path.to_s,
          mode: @mode
        }
      end

      protected
      def convert(value)
        mode = Integer(value)
        raise ArgumentError, "The mode #{format_octet value} must be an octet value between #{format_octet MODE_RANGE.first} and #{format_octet MODE_RANGE.last}" unless MODE_RANGE.cover?(mode)
        mode
      end

      def format_octet(value)
        format("0o%03o", value)
      end
    end

    include Enumerable

    def initialize
      @permitted = []
    end

    def each(&)
      @permitted.each(&)
    end

    def permit(path, **)
      @permitted.append Permit.new(path:, **)
    end

    def permitted?(path, mode: nil)
      if mode
        find { |it| it.permitted_path?(path) and it.permitted_mode?(mode) }
      else
        find { |it| it.permitted_path?(path) }
      end
    end

    def serialize
      map(&:serialize)
    end
  end
end
