# frozen_string_literal: true

module CoverageReporter
  class UncoveredRangesExtractor
    def initialize(coverage_report)
      @coverage_report = coverage_report
    end

    def call
      coverage_map = {}

      return coverage_map unless coverage

      coverage.each do |filename, data|
        # Remove leading slash from file paths for consistency
        normalized_filename = filename.delete_prefix("/")
        ranges = extract_coverage_ranges(data["lines"])
        coverage_map[normalized_filename] = ranges
      end

      coverage_map
    end

    private

    def coverage
      return nil unless @coverage_report.is_a?(Hash)

      @coverage_report["coverage"]
    end

    def extract_coverage_ranges(lines)
      return { actual_ranges: [], display_ranges: [], relevant_ranges: [] } unless lines.is_a?(Array)

      actual_uncovered_lines = []
      display_uncovered_lines = []
      relevant_lines = []
      i = 0

      i = process_line(lines, actual_uncovered_lines, display_uncovered_lines, relevant_lines, i) while i < lines.length

      build_ranges_result(actual_uncovered_lines, display_uncovered_lines, relevant_lines)
    end

    def process_line(lines, actual_lines, display_lines, relevant_lines, index)
      if lines[index] == 0
        process_uncovered_range(lines, actual_lines, display_lines, relevant_lines, index)
      elsif lines[index].is_a?(Numeric) && lines[index] > 0
        add_covered_line(relevant_lines, index)
        index + 1
      else
        index + 1
      end
    end

    def add_covered_line(relevant_lines, index)
      line_number = index + 1
      relevant_lines << line_number
    end

    def build_ranges_result(actual_uncovered_lines, display_uncovered_lines, relevant_lines)
      {
        actual_ranges:   convert_to_ranges(actual_uncovered_lines),
        display_ranges:  convert_to_ranges(display_uncovered_lines),
        relevant_ranges: convert_to_ranges(relevant_lines)
      }
    end

    def process_uncovered_range(lines, actual_lines, display_lines, relevant_lines, start_index)
      i = start_index
      # Found an uncovered line, start a range (always starts with 0)
      line_number = i + 1
      actual_lines << line_number
      display_lines << line_number
      relevant_lines << line_number
      i += 1

      # Continue through consecutive 0s and nils
      # Include nil only if it's immediately followed by an uncovered line (0)
      continue_uncovered_range(lines, actual_lines, display_lines, relevant_lines, i)
    end

    def continue_uncovered_range(lines, actual_lines, display_lines, relevant_lines, start_index)
      i = start_index
      while i < lines.length
        line_number = i + 1
        if lines[i] == 0
          # Actual uncovered line - add to both actual and display, and relevant
          actual_lines << line_number
          display_lines << line_number
          relevant_lines << line_number
          i += 1
        elsif lines[i].nil? && should_continue_range?(lines, i)
          # Nil line that continues the range - add only to display
          display_lines << line_number
          i += 1
        else
          break
        end
      end
      i
    end

    def should_continue_range?(lines, index)
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
