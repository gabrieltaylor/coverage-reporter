# frozen_string_literal: true

module CoverageReporter
  # Analyzes coverage data against diff data to find uncovered lines in changed code
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
  class ModifiedUncoveredIntersection
    def initialize(uncovered_ranges:, modified_ranges:)
      @uncovered_ranges = uncovered_ranges
      @modified_ranges = modified_ranges
    end

    def call
      logger.debug("Starting coverage analysis for #{@modified_ranges.size} modified files")

      intersections = {}

      @modified_ranges.each do |file, modified_ranges|
        next unless @uncovered_ranges.key?(file)
        next if modified_ranges.nil?

        uncovered_ranges = @uncovered_ranges[file] || []
        intersecting_ranges = intersect_ranges(modified_ranges, uncovered_ranges)
        intersections[file] = intersecting_ranges
      end

      logger.debug("Identified modified uncovered intersection: #{intersections}")

      intersections
    end

    private

    def logger
      CoverageReporter.logger
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
  end
end
