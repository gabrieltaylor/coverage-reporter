# frozen_string_literal: true

module CoverageReporter
  class Runner
    def initialize(options)
      @commit_sha    = options[:commit_sha]
      @coverage_path = options[:coverage_path]
      @access_token  = options[:access_token]
      @build_url     = options[:build_url]
      @base_ref      = options[:base_ref]
      @repo          = options[:repo]
      @pr_number     = options[:pr_number]
    end

    def run
      coverage = CoverageParser.new(coverage_path).call
      diff     = DiffParser.new(base_ref).call

      analysis = CoverageAnalyser.new(coverage:, diff:).call
      pull_request = PullRequest.new(access_token:, repo:, pr_number:)

      CommentPoster.new(pull_request:, analysis:, commit_sha:).call
    end

    private

    attr_reader :coverage_path, :access_token, :build_url, :base_ref, :repo, :pr_number, :commit_sha
  end
end
