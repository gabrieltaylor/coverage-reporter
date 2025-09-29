# frozen_string_literal: true

module CoverageReporter
  class GlobalComment
    def initialize(coverage_percentage:, commit_sha:)
      @coverage_percentage = coverage_percentage
      @commit_sha = commit_sha
      @body = build_body
    end

    attr_reader :coverage_percentage, :commit_sha, :body

    private

    def build_body
      <<~MD
        <!-- coverage-comment-marker -->
        🧪 **Test Coverage Summary**

        ✅ **#{coverage_percentage}%** of changed lines are covered.

        _Commit: #{commit_sha}_
      MD
    end
  end
end
