# frozen_string_literal: true

module CoverageReporter
  class CollateRunner
    def initialize(options)
      @coverage_dir = options[:coverage_dir]
      @modified_only = options[:modified_only]
      @github_token = options[:github_token]
      @repo = options[:repo]
      @pr_number = options[:pr_number]
      @working_dir = options[:working_dir]
    end

    def run
      pull_request = PullRequest.new(github_token:, repo:, pr_number:)
      filenames = modified_only ? ModifiedFilesExtractor.new(pull_request.diff).call : []
      CoverageCollator.new(coverage_dir:, filenames:, working_dir:).call
    end

    private

    attr_reader :coverage_dir, :modified_only, :github_token, :repo, :pr_number, :working_dir
  end
end
