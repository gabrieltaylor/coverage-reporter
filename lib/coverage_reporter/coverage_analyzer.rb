# frozen_string_literal: true

module CoverageReporter
  # Analyzes coverage data against diff data to find uncovered lines in changed code
  # and calculates coverage statistics
  #
  # @param uncovered_ranges [Hash] Uncovered data where:
  #   - Keys are filenames (e.g., "app/models/user.rb")
  #   - Values are hashes with :actual_ranges and :display_ranges
  #   - Example: { "app/models/user.rb" => { actual_ranges: [[12,14],[29,30]], display_ranges: [[12,15],[29,30]] } }
  #
  # @param modified_ranges [Hash] Modified data where:
  #   - Keys are filenames (e.g., "app/models/user.rb")
  #   - Values are arrays of arrays representing modified or new line ranges
  #   - Example: { "app/services/foo.rb" => [[100,120]] }
  class CoverageAnalyzer
    def initialize(uncovered_ranges:, modified_ranges:)
      @uncovered_ranges = uncovered_ranges
      @modified_ranges = modified_ranges
    end

    def call
      logger.debug("Starting coverage analysis for #{@modified_ranges.size} modified files")

      accumulator = initialize_accumulator

      @modified_ranges.each do |file, modified_ranges|
        next if skip_file?(modified_ranges)
        next unless file_has_coverage_data?(file)

        file_result = process_file(file, modified_ranges)
        merge_file_result(accumulator, file_result)
      end

      coverage_percentage = calculate_percentage(
        accumulator[:total_modified_lines],
        accumulator[:total_uncovered_modified_lines]
      )

      log_results(accumulator, coverage_percentage)
      build_result(accumulator, coverage_percentage)
    end

    private

    def logger
      CoverageReporter.logger
    end

    def initialize_accumulator
      {
        intersections:                  {},
        total_modified_lines:           0,
        total_uncovered_modified_lines: 0
      }
    end

    def skip_file?(modified_ranges)
      modified_ranges.nil? || modified_ranges.empty?
    end

    def file_has_coverage_data?(file)
      @uncovered_ranges.key?(file)
    end

    def merge_file_result(accumulator, file_result)
      accumulator[:intersections].merge!(file_result[:intersections])
      accumulator[:total_modified_lines] += file_result[:modified_lines]
      accumulator[:total_uncovered_modified_lines] += file_result[:uncovered_lines]
    end

    def process_file(file, modified_ranges)
      file_data = @uncovered_ranges[file] || { actual_ranges: [], display_ranges: [] }
      uncovered_ranges = file_data[:actual_ranges] || []
      intersecting_ranges = find_intersecting_ranges(modified_ranges, uncovered_ranges)

      {
        intersections:   build_file_intersections(file, intersecting_ranges),
        modified_lines:  count_lines_in_ranges(modified_ranges),
        uncovered_lines: count_intersecting_lines(modified_ranges, uncovered_ranges)
      }
    end

    def build_file_intersections(file, intersecting_ranges)
      return {} if intersecting_ranges.empty?

      { file => intersecting_ranges }
    end

    def find_intersecting_ranges(modified_ranges, uncovered_ranges)
      return [] if uncovered_ranges.empty?

      result = []
      modified_index = 0
      uncovered_index = 0

      while modified_index < modified_ranges.size && uncovered_index < uncovered_ranges.size
        modified_range = modified_ranges[modified_index]
        uncovered_range = uncovered_ranges[uncovered_index]

        intersection = calculate_range_intersection(modified_range, uncovered_range)
        result << intersection if intersection

        modified_index, uncovered_index = advance_indices(
          modified_range,
          uncovered_range,
          modified_index,
          uncovered_index
        )
      end

      result
    end

    def calculate_range_intersection(range1, range2)
      start1, end1 = range1
      start2, end2 = range2

      intersection_start = [start1, start2].max
      intersection_end = [end1, end2].min

      return nil if intersection_start > intersection_end

      [intersection_start, intersection_end]
    end

    def advance_indices(modified_range, uncovered_range, modified_index, uncovered_index)
      modified_end = modified_range[1]
      uncovered_end = uncovered_range[1]

      if modified_end < uncovered_end
        [modified_index + 1, uncovered_index]
      else
        [modified_index, uncovered_index + 1]
      end
    end

    def count_intersecting_lines(modified_ranges, uncovered_ranges)
      return 0 if uncovered_ranges.empty?

      total_lines = 0
      modified_index = 0
      uncovered_index = 0

      while modified_index < modified_ranges.size && uncovered_index < uncovered_ranges.size
        modified_range = modified_ranges[modified_index]
        uncovered_range = uncovered_ranges[uncovered_index]

        intersection = calculate_range_intersection(modified_range, uncovered_range)
        total_lines += count_lines_in_range(intersection) if intersection

        modified_index, uncovered_index = advance_indices(
          modified_range,
          uncovered_range,
          modified_index,
          uncovered_index
        )
      end

      total_lines
    end

    def count_lines_in_ranges(ranges)
      ranges.sum { |range| count_lines_in_range(range) }
    end

    def count_lines_in_range(range)
      start_line, end_line = range
      end_line - start_line + 1
    end

    def log_results(accumulator, coverage_percentage)
      logger.debug("Identified modified uncovered intersection: #{accumulator[:intersections]}")
      logger.debug(
        "Coverage calculation: #{accumulator[:total_modified_lines]} total lines, " \
        "#{accumulator[:total_uncovered_modified_lines]} uncovered, " \
        "#{coverage_percentage}% covered"
      )
    end

    def build_result(accumulator, coverage_percentage)
      {
        intersections:  accumulator[:intersections],
        coverage_stats: build_coverage_stats(accumulator, coverage_percentage)
      }
    end

    def build_coverage_stats(accumulator, coverage_percentage)
      total_modified_lines = accumulator[:total_modified_lines]
      uncovered_modified_lines = accumulator[:total_uncovered_modified_lines]

      {
        total_modified_lines:     total_modified_lines,
        uncovered_modified_lines: uncovered_modified_lines,
        covered_modified_lines:   total_modified_lines - uncovered_modified_lines,
        coverage_percentage:      coverage_percentage
      }
    end

    def calculate_percentage(total_lines, uncovered_lines)
      return 100.0 if total_lines == 0

      covered_lines = total_lines - uncovered_lines
      ((covered_lines.to_f / total_lines) * 100).round(2)
    end
  end
end
