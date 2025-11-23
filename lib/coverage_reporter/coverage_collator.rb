# frozen_string_literal: true

module CoverageReporter
  class CoverageCollator
    def initialize(options={})
      @coverage_dir = options[:coverage_dir]
      @filenames = options[:filenames]
      @working_dir = options[:working_dir]
    end

    # rubocop:disable Metrics/AbcSize
    def call
      require "simplecov"
      require "simplecov_json_formatter"
      require "simplecov_hypertext"
      require "coverage_reporter/simple_cov/patches/result_hash_formatter_patch"

      # Collate JSON coverage reports and generate both HTML and JSON outputs
      coverage_files = Dir["#{coverage_dir}/resultset-*.json"]
      abort "No coverage JSON files found to collate" if coverage_files.empty?

      logger.debug("Collate coverage files: #{coverage_files.join(', ')}")
      logger.debug("Working directory: #{working_dir}")
      logger.debug("Filenames: #{filenames}")

      ::SimpleCov.root(working_dir) if working_dir

      ::SimpleCov.collate(coverage_files) do
        filters.clear
        add_filter(build_filter) if filenames.any? && working_dir
        formatter(build_formatter)
      end

      logger.info("✅ Coverage merged and report generated.")
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :coverage_dir, :filenames, :working_dir

    def logger
      CoverageReporter.logger
    end

    def build_formatter
      ::SimpleCov::Formatter::MultiFormatter.new(
        [
          ::SimpleCov::Formatter::JSONFormatter,
          ::SimpleCov::Formatter::HypertextFormatter
        ]
      )
    end

    def build_filter
      lambda do |src_file|
        STDOUT.puts ">>> FILTER CALLED for #{src_file.filename}"
        STDOUT.flush

        normalized_filename = src_file.filename.delete_prefix(working_dir).delete_prefix("/")
        STDOUT.puts "Normalized filename: #{normalized_filename}"
        STDOUT.puts "Filenames: #{filenames.inspect}"
        STDOUT.flush
        filenames.none?(normalized_filename)
      end
    end
  end
end
