# frozen_string_literal: true

require "logger"
require "octokit"

module CoverageReporter
  # Comment markers for identifying coverage-related comments
  INLINE_COMMENT_MARKER = "<!-- coverage-inline-marker -->"
  GLOBAL_COMMENT_MARKER = "<!-- coverage-comment-marker -->"

  autoload :CLI, "coverage_reporter/cli"
  autoload :VERSION, "coverage_reporter/version"

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = name
        log.level = ENV["COVERAGE_REPORTER_LOG_LEVEL"]&.upcase || "INFO"
      end
    end
  end

  require_relative "coverage_reporter/coverage_report_loader"
  require_relative "coverage_reporter/modified_uncovered_intersection"
  require_relative "coverage_reporter/global_comment"
  require_relative "coverage_reporter/global_comment_factory"
  require_relative "coverage_reporter/global_comment_poster"
  require_relative "coverage_reporter/inline_comment"
  require_relative "coverage_reporter/inline_comment_factory"
  require_relative "coverage_reporter/inline_comment_poster"
  require_relative "coverage_reporter/modified_ranges_extractor"
  require_relative "coverage_reporter/options"
  require_relative "coverage_reporter/pull_request"
  require_relative "coverage_reporter/runner"
  require_relative "coverage_reporter/uncovered_ranges_extractor"
  require_relative "coverage_reporter/simple_cov/patches/result_hash_formatter_patch"
end
