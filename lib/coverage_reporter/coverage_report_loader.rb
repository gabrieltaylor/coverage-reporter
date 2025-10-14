# frozen_string_literal: true

require "json"

module CoverageReporter
  # Custom error classes for coverage file operations
  class CoverageFileError < StandardError; end
  class CoverageFileNotFoundError < CoverageFileError; end
  class CoverageFileAccessError < CoverageFileError; end
  class CoverageFileParseError < CoverageFileError; end

  class CoverageReportLoader
    def initialize(coverage_file_path)
      @coverage_file_path = coverage_file_path
    end

    def call
      content = read_file_content
      parse_json_content(content)
    rescue Errno::ENOENT
      raise CoverageFileNotFoundError, "Coverage file not found: #{@coverage_file_path}"
    rescue Errno::EACCES
      raise CoverageFileAccessError, "Permission denied reading coverage file: #{@coverage_file_path}"
    rescue JSON::ParserError => e
      raise CoverageFileParseError, "Invalid JSON in coverage file #{@coverage_file_path}: #{e.message}"
    rescue => e
      raise CoverageFileError, "Unexpected error reading coverage file #{@coverage_file_path}: #{e.message}"
    end

    private

    attr_reader :coverage_file_path

    def read_file_content
      File.read(@coverage_file_path)
    end

    def parse_json_content(content)
      JSON.parse(content)
    end
  end
end
