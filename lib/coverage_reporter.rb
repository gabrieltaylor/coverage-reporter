# frozen_string_literal: true

module CoverageReporter
  autoload :CLI, "coverage_reporter/cli"
  autoload :VERSION, "coverage_reporter/version"

  require_relative "coverage_reporter/comment_poster"
  require_relative "coverage_reporter/coverage_analyser"
  require_relative "coverage_reporter/coverage_parser"
  require_relative "coverage_reporter/diff_parser"
  require_relative "coverage_reporter/options"
  require_relative "coverage_reporter/pull_request"
  require_relative "coverage_reporter/runner"
end
