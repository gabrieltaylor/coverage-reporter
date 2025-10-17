# frozen_string_literal: true

module CoverageReporter
  class UncoveredRangesExtractor
    def initialize(coverage_report)
      @coverage_report = coverage_report
    end

    def call
      coverage_map = Hash.new { |h, k| h[k] = [] }

      return coverage_map unless coverage

      coverage.each do |filename, data|
        # Remove leading slash from file paths for consistency
        normalized_filename = filename.start_with?("/") ? filename[1..] : filename
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
  end
end
