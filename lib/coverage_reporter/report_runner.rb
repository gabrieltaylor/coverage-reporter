# frozen_string_literal: true

module CoverageReporter
  class ReportRunner
    def initialize(options)
      @commit_sha           = options[:commit_sha]
      @coverage_report_path = options[:coverage_report_path]
      @github_token         = options[:github_token]
      @report_url           = options[:report_url]
      @repo                 = options[:repo]
      @pr_number            = options[:pr_number]
    end

    # rubocop:disable Metrics/AbcSize
    def run
      pull_request = PullRequest.new(github_token:, repo:, pr_number:)
      coverage_report = CoverageReportLoader.new(coverage_report_path).call
      modified_ranges = ModifiedRangesExtractor.new(pull_request.diff).call
      coverage_ranges = CoverageRangesExtractor.new(coverage_report).call
      analysis_result = CoverageAnalyzer.new(coverage_ranges:, modified_ranges:).call
      intersection = analysis_result[:intersections]
      coverage_stats = analysis_result[:coverage_stats]
      inline_comments = InlineCommentFactory.new(intersection:, commit_sha:).call
      InlineCommentPoster.new(pull_request:, commit_sha:, inline_comments:).call
      global_comment = GlobalComment.new(
        commit_sha:,
        report_url:,
        coverage_percentage: coverage_stats[:coverage_percentage],
        intersections:       intersection
      )
      GlobalCommentPoster.new(pull_request:, global_comment:).call
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :coverage_report_path, :github_token, :report_url, :repo, :pr_number, :commit_sha
  end
end
