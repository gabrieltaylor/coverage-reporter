# frozen_string_literal: true

module CoverageReporter
  class Runner
    def initialize(options)
      @commit_sha    = options[:commit_sha]
      @coverage_path = options[:coverage_path]
      @github_token  = options[:github_token]
      @build_url     = options[:build_url]
      @repo          = options[:repo]
      @pr_number     = options[:pr_number]
    end

    def run
      pull_request = PullRequest.new(github_token:, repo:, pr_number:)
      diff = DiffParser.new(pull_request.diff).call
      coverage = CoverageParser.new(coverage_path).call
      analysis = CoverageAnalyser.new(coverage:, diff:).call

      CommentPoster.new(pull_request:, analysis:, commit_sha:).call
    end

    private

    attr_reader :coverage_path, :github_token, :build_url, :repo, :pr_number, :commit_sha
  end
end
