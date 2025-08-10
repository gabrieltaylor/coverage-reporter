# frozen_string_literal: true

module CoverageReporter
  class CoverageStats
    attr_reader :total, :covered, :uncovered

    def initialize(coverage, diff)
      @total = 0
      @covered = 0
      @uncovered = {}

      diff.each do |file, lines|
        @total += lines.size
        covered_lines = coverage[file] || []
        cov = lines & covered_lines
        @covered += cov.size
        missed = lines - covered_lines
        @uncovered[file] = missed if missed.any?
      end
    end

    def diff_coverage
      total > 0 ? (covered * 100.0 / total).round(2) : 100.0
    end
  end
end
