
# frozen_string_literal: true

module CoverageReporter
  class CollateRunner
    def initialize(options)
      @coverage_dir = options[:coverage_dir]
      @modified_only = options[:modified_only]
      @github_token = options[:github_token]
      @repo = options[:repo]
      @pr_number = options[:pr_number]
    end

    def run
      pull_request = PullRequest.new(github_token:, repo:, pr_number:)
      filter = modified_only ? ModifiedFilesExtractor.new(pull_request.diff).call : []
      CoverageCollator.new(coverage_dir:, filter:).call
    end

    private

    attr_reader :coverage_dir, :modified_only, :github_token, :repo, :pr_number
  end
end
