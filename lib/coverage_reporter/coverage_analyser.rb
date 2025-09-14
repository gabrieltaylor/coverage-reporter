# frozen_string_literal: true

module CoverageReporter
  # Analyzes coverage data against diff data to find uncovered lines in changed code
  #
  # @param coverage [Hash] Coverage data where:
  #   - Keys are filenames (e.g., "app/models/user.rb")
  #   - Values are arrays of ranges representing uncovered lines
  #   - Example: { "app/models/user.rb" => [[12,14],[29,30]] }
  #
  # @param diff [Hash] Diff data where:
  #   - Keys are filenames (e.g., "app/models/user.rb")
  #   - Values are arrays of arrays representing modified or new line ranges
  #   - Example: { "app/services/foo.rb" => [[100,120]] }
  class CoverageAnalyser
    def initialize(coverage:, diff:)
      @coverage = coverage
      @diff     = diff
    end

    def call
      uncovered_map = {}

      @diff.each do |file, changed_ranges|
        next unless @coverage.key?(file)
        next if changed_ranges.nil?

        uncovered_ranges = @coverage[file] || []
        overlapping_ranges = intersect_ranges(changed_ranges, uncovered_ranges)
        uncovered_map[file] = overlapping_ranges
      end

      uncovered_map
    end

    private

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
  end
end
