# frozen_string_literal: true

require "json"

module CoverageReporter
  class CoverageParser
    def initialize(coverage_file_path)
      @coverage_file_path = coverage_file_path
    end

    def call
      coverage_map = Hash.new { |h, k| h[k] = [] }

      coverage.each do |filename, data|
        normalized_filename = normalize_filename(filename)
        uncovered_ranges = extract_uncovered_ranges(data["lines"])
        coverage_map[normalized_filename] = uncovered_ranges
      end

      coverage_map
    end

    private

    def coverage
      return {} unless File.file?(@coverage_file_path)

      content = File.read(@coverage_file_path)
      JSON.parse(content)["coverage"]
    rescue StandardError
      {}
    end

    def extract_uncovered_ranges(lines)
      uncovered_lines = []
      lines.each_with_index do |count, idx|
        # Only lines with 0 count are considered uncovered
        # null values are not relevant for coverage
        uncovered_lines << (idx + 1) if count == 0
      end
      convert_to_ranges(uncovered_lines)
    end

    def convert_to_ranges(lines)
      return [] if lines.empty?

      ranges = []
      start_line = lines.first
      end_line = lines.first

      lines.each_cons(2) do |current, next_line|
        if next_line == current + 1
          # Consecutive lines, extend the range
          end_line = next_line
        else
          # Gap found, close current range and start new one
          ranges << [start_line, end_line]
          start_line = next_line
          end_line = next_line
        end
      end

      # Add the last range
      ranges << [start_line, end_line]
      ranges
    end

    def normalize_filename(file_path)
      return nil if file_path.nil? || file_path.empty?

      # Use current working directory as project root
      project_root = Dir.pwd

      # If the file path starts with the project root, remove that prefix
      if file_path.start_with?(project_root)
        file_path.delete_prefix(project_root).delete_prefix("/")
      else
        # If it doesn't start with project root, return as-is (assuming it's already relative)
        file_path
      end
    end
  end
end
