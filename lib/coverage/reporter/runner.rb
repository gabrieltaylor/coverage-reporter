# frozen_string_literal: true

require_relative "coverage_parser"
require_relative "diff_parser"
require_relative "github_api"
require_relative "coverage_analyzer"
require_relative "chunker"
require_relative "comment_formatter"
require_relative "comment_publisher"

module CoverageReporter
  class Runner
    def initialize(options)
      @coverage_path = options[:coverage_path]
      @html_root     = options[:html_root]
      @github_token  = options[:github_token]
      @build_url     = options[:build_url]
      @base_ref      = options[:base_ref]
    end

    def run
      coverage = CoverageParser.new(@coverage_path).parse
      diff     = DiffParser.new(@base_ref).fetch_diff

      analysis = CoverageAnalyzer.new(coverage: coverage, diff: diff).analyze
      github   = GitHubAPI.new(@github_token, @build_url, @html_root)

      publisher = CommentPublisher.new(
        github:    github,
        chunker:   Chunker.new,
        formatter: CommentFormatter.new(github: github)
      )

      pr_number = github.find_pr_number
      publisher.publish_inline(pr_number: pr_number, uncovered_by_file: analysis.uncovered_by_file)
      publisher.publish_global(pr_number: pr_number, diff_coverage: analysis.diff_coverage)
    end
  end
end
