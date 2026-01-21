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
        log.level = valid_log_level(ENV.fetch("COVERAGE_REPORTER_LOG_LEVEL", nil))
      end
    end

    private

    def valid_log_level(env_level)
      return "INFO" if env_level.nil? || env_level.empty?

      level = env_level.upcase
      valid_levels = %w[DEBUG INFO WARN ERROR]

      valid_levels.include?(level) ? level : "INFO"
    end
  end

  require_relative "coverage_reporter/coverage_analyzer"
  require_relative "coverage_reporter/coverage_collator"
  require_relative "coverage_reporter/coverage_report_loader"
  require_relative "coverage_reporter/global_comment"
  require_relative "coverage_reporter/global_comment_poster"
  require_relative "coverage_reporter/inline_comment"
  require_relative "coverage_reporter/inline_comment_factory"
  require_relative "coverage_reporter/inline_comment_poster"
  require_relative "coverage_reporter/modified_files_extractor"
  require_relative "coverage_reporter/modified_ranges_extractor"
  require_relative "coverage_reporter/options/base"
  require_relative "coverage_reporter/options/collate"
  require_relative "coverage_reporter/options/report"
  require_relative "coverage_reporter/pull_request"
  require_relative "coverage_reporter/report_runner"
  require_relative "coverage_reporter/collate_runner"
  require_relative "coverage_reporter/coverage_ranges_extractor"
  require_relative "coverage_reporter/simple_cov/patches/result_hash_formatter_patch"
end
