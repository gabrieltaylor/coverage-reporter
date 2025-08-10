# frozen_string_literal: true

module CoverageReporter
  AnalysisResult = Data.new(:total_changed, :total_covered, :diff_coverage, :uncovered_by_file, keyword_init: true)

  class CoverageAnalyzer
    def initialize(coverage:, diff:)
      @coverage = coverage # { "path/file.rb" => [covered_line_numbers] }
      @diff     = diff     # { "path/file.rb" => [changed_line_numbers] }
    end

    # rubocop:disable Metrics/AbcSize
    def analyze
      total = 0
      covered = 0
      uncovered_map = {}

      @diff.each do |file, lines|
        next unless lines && !lines.empty?

        total += lines.size
        covered_lines = Array(@coverage[file])
        covered += (lines & covered_lines).size
        missed = lines - covered_lines
        uncovered_map[file] = missed if missed.any?
      end

      diff_cov = total > 0 ? (covered * 100.0 / total).round(2) : 100.0

      AnalysisResult.new(
        total_changed:     total,
        total_covered:     covered,
        diff_coverage:     diff_cov,
        uncovered_by_file: uncovered_map
      )
    end
    # rubocop:enable Metrics/AbcSize
  end
end
