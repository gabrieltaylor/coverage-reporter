#!/usr/bin/env ruby
# frozen_string_literal: true

require "vcr"
require "webmock"
require "coverage_reporter"

# Configure VCR to record real HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record:            :new_episodes,
    match_requests_on: %i[method uri body]
  }
end

# Create fixtures directory if it doesn't exist
FileUtils.mkdir_p("spec/fixtures/vcr_cassettes")

def build_options
  {
    github_token:         ENV.fetch("GITHUB_TOKEN", nil),
    repo:                 ENV["REPO"] || "your-org/your-repo",
    pr_number:            ENV["PR_NUMBER"] || "123",
    commit_sha:           ENV["COMMIT_SHA"] || "abc123def456",
    coverage_report_path: ENV["COVERAGE_REPORT_PATH"] || "coverage/coverage.json",
    build_url:            ENV["BUILD_URL"] || "https://ci.example.com/build/123"
  }
end

def validate_options(options)
  return if options[:github_token]

  puts "Error: GITHUB_TOKEN environment variable is required"
  exit 1
end

def print_capture_info(options)
  puts "Capturing interactions for PR ##{options[:pr_number]} in #{options[:repo]}"
  puts "Commit SHA: #{options[:commit_sha]}"
  puts "Coverage report: #{options[:coverage_report_path]}"
end

def run_coverage_reporter(options)
  VCR.use_cassette("real_pr_#{options[:pr_number]}") do
    runner = CoverageReporter::Runner.new(options)
    runner.run
    puts "✅ Successfully captured interactions!"
  rescue StandardError => e
    puts "❌ Error during execution: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end

def capture_pr_interactions
  options = build_options
  validate_options(options)
  print_capture_info(options)
  run_coverage_reporter(options)
  puts "📁 Cassette saved to: spec/fixtures/vcr_cassettes/real_pr_#{options[:pr_number]}.yml"
end

# Run the capture
capture_pr_interactions
