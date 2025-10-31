# frozen_string_literal: true

module CoverageReporter
  class CoverageCollator
    def initialize(options={})
      @coverage_dir = options[:coverage_dir]
      @filter= options[:filter]
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
        add_filter(filter)
        formatter(::SimpleCov::Formatter::MultiFormatter.new(formats))
      end

      puts "✅ Coverage merged and report generated."
    end

    private

    attr_reader :coverage_dir, :filter

    def formats
      [
        ::SimpleCov::Formatter::JSONFormatter,
        ::SimpleCov::Formatter::HypertextFormatter,
      ]
    end
  end
end
