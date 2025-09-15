# frozen_string_literal: true

require "logger"
require "octokit"

module CoverageReporter
  autoload :CLI, "coverage_reporter/cli"
  autoload :VERSION, "coverage_reporter/version"

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
        log.level = ENV['COVERAGE_REPORTER_LOG_LEVEL']&.upcase || 'INFO'
      end
    end
  end

  require_relative "coverage_reporter/comment_poster"
  require_relative "coverage_reporter/coverage_analyser"
  require_relative "coverage_reporter/coverage_parser"
  require_relative "coverage_reporter/diff_parser"
  require_relative "coverage_reporter/options"
  require_relative "coverage_reporter/pull_request"
  require_relative "coverage_reporter/runner"
end
