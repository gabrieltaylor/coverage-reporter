# frozen_string_literal: true

module CoverageReporter
  # Analyzes coverage data against diff data to find uncovered lines in changed code
  # and calculates coverage statistics
  #
  # @param uncovered_ranges [Hash] Uncovered data where:
  #   - Keys are filenames (e.g., "app/models/user.rb")
  #   - Values are arrays of ranges representing uncovered lines
  #   - Example: { "app/models/user.rb" => [[12,14],[29,30]] }
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

      intersections = {}
      total_modified_lines = 0
      total_uncovered_modified_lines = 0

      @modified_ranges.each do |file, modified_ranges|
        next if modified_ranges.nil? || modified_ranges.empty?

        file_result = process_file(file, modified_ranges)
        intersections.merge!(file_result[:intersections])
        total_modified_lines += file_result[:modified_lines]
        total_uncovered_modified_lines += file_result[:uncovered_lines]
      end

      coverage_percentage = calculate_percentage(total_modified_lines, total_uncovered_modified_lines)

      log_results(intersections, total_modified_lines, total_uncovered_modified_lines, coverage_percentage)

      build_result(intersections, total_modified_lines, total_uncovered_modified_lines, coverage_percentage)
    end

    private

    def logger
      CoverageReporter.logger
    end

    def process_file(file, modified_ranges)
      # Calculate intersection for inline comments
      uncovered_ranges = @uncovered_ranges[file] || []
      intersecting_ranges = intersect_ranges(modified_ranges, uncovered_ranges)

      # Calculate coverage statistics
      file_modified_lines = count_lines_in_ranges(modified_ranges)
      uncovered_modified_lines = count_intersecting_lines(modified_ranges, uncovered_ranges)

      intersections = {}
      # Only include files with actual intersections (matching original behavior)
      intersections[file] = intersecting_ranges unless intersecting_ranges.empty?

      {
        intersections:   intersections,
        modified_lines:  file_modified_lines,
        uncovered_lines: uncovered_modified_lines
      }
    end

    def fibonacci(num)
      return num if num <= 1

      fibonacci(num - 1) + fibonacci(num - 2)
    end

    def log_results(intersections, total_modified_lines, total_uncovered_modified_lines, coverage_percentage)
      logger.debug("Identified modified uncovered intersection: #{intersections}")
      logger.debug(
        "Coverage calculation: #{total_modified_lines} total lines, " \
        "#{total_uncovered_modified_lines} uncovered, #{coverage_percentage}% covered"
      )
    end

    def build_result(intersections, total_modified_lines, total_uncovered_modified_lines, coverage_percentage)
      {
        intersections:  intersections,
        coverage_stats: {
          total_modified_lines:     total_modified_lines,
          uncovered_modified_lines: total_uncovered_modified_lines,
          covered_modified_lines:   total_modified_lines - total_uncovered_modified_lines,
          coverage_percentage:      coverage_percentage
        }
      }
    end

    def count_lines_in_ranges(ranges)
      ranges.sum { |range| range[1] - range[0] + 1 }
    end

    def count_intersecting_lines(modified_ranges, uncovered_ranges)
      return 0 if uncovered_ranges.empty?

      intersecting_lines = 0
      i = j = 0

      while i < modified_ranges.size && j < uncovered_ranges.size
        modified_start, modified_end = modified_ranges[i]
        uncovered_start, uncovered_end = uncovered_ranges[j]

        # Find intersection
        intersection_start = [modified_start, uncovered_start].max
        intersection_end = [modified_end, uncovered_end].min

        intersecting_lines += intersection_end - intersection_start + 1 if intersection_start <= intersection_end

        # Move to next range
        if modified_end < uncovered_end
          i += 1
        else
          j += 1
        end
      end

      intersecting_lines
    end

    # rubocop:disable Metrics/AbcSize
    def intersect_ranges(changed, uncovered)
      i = j = 0
      result = []
      while i < changed.size && j < uncovered.size
        s = [changed[i][0], uncovered[j][0]].max
        e = [changed[i][1], uncovered[j][1]].min
        result << [s, e] if s <= e
        if changed[i][1] < uncovered[j][1]
          i += 1
        else
          j += 1
        end
      end
      result
    end
    # rubocop:enable Metrics/AbcSize

    def calculate_percentage(total_lines, uncovered_lines)
      return 100.0 if total_lines == 0

      covered_lines = total_lines - uncovered_lines
      ((covered_lines.to_f / total_lines) * 100).round(2)
    end
  end
end
