# frozen_string_literal: true

module CoverageReporter
  class CoverageCollator
    def initialize(options={})
      @coverage_dir = options[:coverage_dir]
    end

    def call
      require "simplecov"
      require "simplecov_json_formatter"
      require "coverage_reporter/simple_cov/patches/result_hash_formatter_patch"

      # Collate JSON coverage reports and generate both HTML and JSON outputs
      files = Dir["#{coverage_dir}/resultset-*.json"]
      abort "No coverage JSON files found to collate" if files.empty?

      puts "Collate coverage files: #{files.join(', ')}"

      ::SimpleCov.collate(files) do
        formatter ::SimpleCov::Formatter::MultiFormatter.new(
          [
            ::SimpleCov::Formatter::HTMLFormatter,
            ::SimpleCov::Formatter::JSONFormatter
          ]
        )
      end

      puts "✅ Coverage merged and report generated."
    end

    private

    attr_reader :coverage_dir
  end
end
