# frozen_string_literal: true

module CoverageReporter
  class Runner
    def initialize(options)
      @coverage_path = options[:coverage_path]
      @html_root     = options[:html_root]
      @access_token  = options[:access_token]
      @build_url     = options[:build_url]
      @base_ref      = options[:base_ref]
    end

    def run
      coverage = CoverageParser.new(coverage_path).call
      diff     = DiffParser.new(base_ref).call

      analysis = CoverageAnalyser.new(coverage:, diff:).call
      pull_request = PullRequest.new(access_token:, repo:, pr_number:)

      CommentPoster.new(pull_request:, analysis:).call
    end

    private

    attr_reader :coverage_path, :html_root, :access_token, :build_url, :base_ref
  end
end
