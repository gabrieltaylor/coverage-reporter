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
      coverage = CoverageParser.new(coverage_path).parse
      diff     = DiffParser.new(base_ref).fetch_diff

      analysis = CoverageAnalyser.new(coverage:, diff:).analyze
      pull_request = PullRequest.new(access_token:, repo:, pr_number:)

      CommentPoster.new(pull_request:, status:).post_all
    end

    private

    attr_reader :coverage_path, :html_root, :access_token, :build_url, :base_ref
  end
end
