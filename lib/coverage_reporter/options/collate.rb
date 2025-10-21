# frozen_string_literal: true

require "optparse"

module CoverageReporter
  module Options
    class Collate < Base
      def self.defaults
        {
          coverage_dir: "coverage"
        }
      end

      def self.parse(argv)
        opts = defaults.dup

        parser = OptionParser.new do |o|
          o.banner = "Usage: coverage-reporter collate [options]"
          o.on("--coverage-dir DIR", "Directory containing coverage files (default: coverage)") do |v|
            opts[:coverage_dir] = v
          end
          o.on_tail("-h", "--help", "Show help") do
            puts o
            exit 0
          end
        end

        parser.parse!(argv)
        opts
      end
    end
  end
end
