#!/usr/bin/env ruby
# frozen_string_literal: true

require "logger"
require "coverage_reporter"

# Set up logging
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
CoverageReporter.logger = logger

# Override Octokit's logger to capture more details
require "octokit"
Octokit.configure do |config|
  config.logger = logger
end

# Monkey patch to log HTTP requests
module Octokit
  class Client
    alias_method :request_without_logging, :request
    
    def request(method, path, data = {}, options = {})
      logger.debug("🌐 #{method.upcase} #{path}")
      logger.debug("📤 Request data: #{data.inspect}") if data.any?
      
      response = request_without_logging(method, path, data, options)
      
      logger.debug("📥 Response status: #{response.status}")
      logger.debug("📥 Response body: #{response.body[0..500]}...") if response.body && response.body.length > 500
      
      response
    end
  end
end

puts "🚀 Running coverage-reporter with detailed logging..."
puts "Set environment variables:"
puts "  GITHUB_TOKEN=your_token"
puts "  REPO=owner/repo"
puts "  PR_NUMBER=123"
puts "  COMMIT_SHA=abc123"
puts "  COVERAGE_REPORT_PATH=coverage/coverage.json"
puts "  BUILD_URL=https://ci.example.com/build/123"
puts ""

# Run the CLI with the provided arguments
CoverageReporter::CLI.start(ARGV)
