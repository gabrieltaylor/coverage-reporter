# frozen_string_literal: true

module CoverageReporter
  class Runner
    def initialize(options)
      @commit_sha           = options[:commit_sha]
      @coverage_report_path = options[:coverage_report_path]
      @github_token         = options[:github_token]
      @build_url            = options[:build_url]
      @repo                 = options[:repo]
      @pr_number            = options[:pr_number]
    end

    # rubocop:disable Metrics/AbcSize
    def run
      pull_request = PullRequest.new(github_token:, repo:, pr_number:)
      coverage_report = CoverageReportLoader.new(coverage_report_path).call
      modified_ranges = ModifiedRangesExtractor.new(pull_request.diff).call
      uncovered_ranges = UncoveredRangesExtractor.new(coverage_report).call
      intersection = ModifiedUncoveredIntersection.new(uncovered_ranges:, modified_ranges:).call
      inline_comments = InlineCommentFactory.new(intersection:, commit_sha:).call
      InlineCommentPoster.new(pull_request:, commit_sha:, inline_comments:).call
      global_comment = GlobalCommentFactory.new(commit_sha:).call
      GlobalCommentPoster.new(pull_request:, global_comment:).call
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :coverage_report_path, :github_token, :build_url, :repo, :pr_number, :commit_sha
  end
end
