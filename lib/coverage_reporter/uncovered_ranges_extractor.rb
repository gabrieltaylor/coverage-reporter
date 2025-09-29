# frozen_string_literal: true

require "json"

module CoverageReporter
  class UncoveredRangesExtractor
    def initialize(coverage_report)
      @coverage_report = coverage_report
    end

    def call
      coverage_map = Hash.new { |h, k| h[k] = [] }

      return coverage_map unless coverage

      coverage.each do |filename, data|
        normalized_filename = normalize_filename(filename)
        uncovered_ranges = extract_uncovered_ranges(data["lines"])
        coverage_map[normalized_filename] = uncovered_ranges
      end

      coverage_map
    end

    private

    def coverage
      return nil unless @coverage_report.is_a?(Hash)

      @coverage_report["coverage"]
    end

    def extract_uncovered_ranges(lines)
      return [] unless lines.is_a?(Array)

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
        # If it's an absolute path but doesn't start with current project root,
        # extract the relative path by finding the last occurrence of common project structure
        if file_path.start_with?("/")
          # Try to extract relative path from absolute path
          # Look for common patterns like /path/to/project/lib/... or /path/to/project/spec/...
          if file_path.include?("/lib/") || file_path.include?("/spec/")
            # Extract everything after the last occurrence of /lib/ or /spec/
            if file_path.include?("/lib/")
              lib_index = file_path.rindex("/lib/")
              file_path[lib_index + 1..-1] # Include the leading slash
            elsif file_path.include?("/spec/")
              spec_index = file_path.rindex("/spec/")
              file_path[spec_index + 1..-1] # Include the leading slash
            end
          else
            # Fallback: return as-is (assuming it's already relative)
            file_path
          end
        else
          # Already relative, return as-is
          file_path
        end
      end
    end
  end
end
