# frozen_string_literal: true

module CoverageReporter
  class GlobalCommentFactory
    def initialize(commit_sha:)
      @commit_sha = commit_sha
    end

    def call
      coverage_percentage = calculate_coverage_percentage
      GlobalComment.new(
        coverage_percentage: coverage_percentage,
        commit_sha:          commit_sha
      )
    end

    private

    attr_reader :commit_sha

    def calculate_coverage_percentage
      # Since we only have uncovered ranges, we can't calculate exact coverage percentage
      # without knowing the total changed lines. For now, return a placeholder.
      # This could be enhanced to accept total changed lines as a parameter.
      "N/A"
    end
  end
end
