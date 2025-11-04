# frozen_string_literal: true

module CoverageReporter
  class CoverageCollator
    def initialize(options={})
      @coverage_dir = options[:coverage_dir]
      @filenames = options[:filenames]
    end

    def call
      require "simplecov"
      require "simplecov_json_formatter"
      require "simplecov_hypertext"
      require "coverage_reporter/simple_cov/patches/result_hash_formatter_patch"

      # Collate JSON coverage reports and generate both HTML and JSON outputs
      coverage_files = Dir["#{coverage_dir}/resultset-*.json"]
      abort "No coverage JSON files found to collate" if coverage_files.empty?

      puts "Collate coverage files: #{coverage_files.join(', ')}"

      ::SimpleCov.collate(coverage_files) do
        add_filter(build_filter) if filenames.any?
        formatter(build_formatter)
      end

      puts "✅ Coverage merged and report generated."
    end

    private

    attr_reader :coverage_dir, :filenames

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
        filenames.none?(File.basename(src_file.filename))
      end
    end
  end
end
