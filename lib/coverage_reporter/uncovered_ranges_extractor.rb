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
      i = 0

      while i < lines.length
        if lines[i] == 0
          i = process_uncovered_range(lines, uncovered_lines, i)
        else
          i += 1
        end
      end

      convert_to_ranges(uncovered_lines)
    end

    def process_uncovered_range(lines, uncovered_lines, start_index)
      i = start_index
      # Found an uncovered line, start a range (always starts with 0)
      uncovered_lines << (i + 1)
      i += 1

      # Continue through consecutive 0s and nils
      # Include nil only if it's immediately followed by an uncovered line (0)
      continue_uncovered_range(lines, uncovered_lines, i)
    end

    def continue_uncovered_range(lines, uncovered_lines, start_index)
      i = start_index
      while i < lines.length
        break unless should_continue_range?(lines, i)

        uncovered_lines << (i + 1)
        i += 1
      end
      i
    end

    def should_continue_range?(lines, index)
      return true if lines[index] == 0
      return false unless lines[index].nil?

      # Include nil only if it's immediately followed by an uncovered line (0)
      index + 1 < lines.length && lines[index + 1] == 0
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
