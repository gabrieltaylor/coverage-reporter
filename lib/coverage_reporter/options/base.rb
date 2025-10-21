# frozen_string_literal: true

module CoverageReporter
  module Options
    # Interface class that defines the contract for option classes
    class Base
      # Returns a hash of default options
      def self.defaults
        raise NotImplementedError, "Subclasses must implement #{__method__}"
      end

      # Parses command line arguments and returns a hash of options
      # @param argv [Array<String>] Command line arguments
      # @return [Hash] Parsed options
      def self.parse(argv)
        raise NotImplementedError, "Subclasses must implement #{__method__}"
      end
    end
  end
end
