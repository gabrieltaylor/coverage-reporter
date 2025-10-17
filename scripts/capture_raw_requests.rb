#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "coverage_reporter"
require "fileutils"

# Custom HTTP interceptor to capture raw requests/responses
class RequestCapture
  def initialize
    @requests = []
    @responses = []
  end

  def capture_request(method, uri, headers, body)
    request_data = {
      method:    method,
      uri:       uri.to_s,
      headers:   headers,
      body:      body,
      timestamp: Time.now.iso8601
    }
    @requests << request_data
    puts "📤 Captured #{method} request to #{uri}"
  end

  def capture_response(status, headers, body)
    response_data = {
      status:    status,
      headers:   headers,
      body:      body,
      timestamp: Time.now.iso8601
    }
    @responses << response_data
    puts "📥 Captured response: #{status}"
  end

  def save_to_file(filename)
    data = {
      requests:    @requests,
      responses:   @responses,
      captured_at: Time.now.iso8601
    }

    File.write(filename, JSON.pretty_generate(data))
    puts "💾 Saved #{@requests.length} requests and #{@responses.length} responses to #{filename}"
  end
end

# Monkey patch Octokit to capture requests
module OctokitCapture
  def self.included(base)
    base.class_eval do
      alias_method :request_without_capture, :request

      def request(method, path, data={}, options={})
        # Capture the request
        uri = URI.join(@api_endpoint, path)
        @capture&.capture_request(method, uri, options[:headers] || {}, data.to_json)

        # Make the actual request
        response = request_without_capture(method, path, data, options)

        # Capture the response
        @capture&.capture_response(response.status, response.headers, response.body)

        response
      end
    end
  end
end

def build_capture_options
  {
    github_token:         ENV.fetch("GITHUB_TOKEN", nil),
    repo:                 ENV["REPO"] || "your-org/your-repo",
    pr_number:            ENV["PR_NUMBER"] || "123",
    commit_sha:           ENV["COMMIT_SHA"] || "abc123def456",
    coverage_report_path: ENV["COVERAGE_REPORT_PATH"] || "coverage/coverage.json",
    report_url:           ENV["REPORT_URL"] || "https://ci.example.com/build/123"
  }
end

def validate_capture_options(options)
  return if options[:github_token]

  puts "Error: GITHUB_TOKEN environment variable is required"
  exit 1
end

def print_capture_info(options)
  puts "🔍 Capturing raw HTTP interactions for PR ##{options[:pr_number]} in #{options[:repo]}"
  puts "Commit SHA: #{options[:commit_sha]}"
  puts "Coverage report: #{options[:coverage_report_path]}"
end

def setup_capture_environment
  capture = RequestCapture.new
  FileUtils.mkdir_p("spec/fixtures/raw_requests")
  capture
end

def create_pull_request_with_capture(options, capture)
  pull_request = CoverageReporter::PullRequest.new(
    github_token: options[:github_token],
    repo:         options[:repo],
    pr_number:    options[:pr_number]
  )

  # Inject capture into the Octokit client
  client = pull_request.instance_variable_get(:@client)
  client.extend(OctokitCapture)
  client.instance_variable_set(:@capture, capture)
  pull_request
end

def load_coverage_data(options, pull_request)
  coverage_report = CoverageReporter::CoverageReportLoader.new(options[:coverage_report_path]).call
  modified_ranges = CoverageReporter::ModifiedRangesExtractor.new(pull_request.diff).call
  uncovered_ranges = CoverageReporter::UncoveredRangesExtractor.new(coverage_report).call

  CoverageReporter::ModifiedUncoveredIntersection.new(
    uncovered_ranges: uncovered_ranges,
    modified_ranges:  modified_ranges
  ).call
end

def post_inline_comments(options, pull_request, intersection)
  inline_comments = CoverageReporter::InlineCommentFactory.new(
    intersection: intersection,
    commit_sha:   options[:commit_sha]
  )

  CoverageReporter::InlineCommentPoster.new(
    pull_request:    pull_request,
    commit_sha:      options[:commit_sha],
    inline_comments: inline_comments
  ).call
end

def post_global_comment(options, pull_request)
  global_comment = CoverageReporter::GlobalComment.new(
    commit_sha: options[:commit_sha],
    report_url: options[:report_url]
  )

  CoverageReporter::GlobalCommentPoster.new(
    pull_request:   pull_request,
    global_comment: global_comment
  ).call
end

def run_coverage_workflow(options, pull_request)
  intersection = load_coverage_data(options, pull_request)
  post_inline_comments(options, pull_request, intersection)
  post_global_comment(options, pull_request)
end

def save_successful_capture(capture, options)
  filename = "spec/fixtures/raw_requests/pr_#{options[:pr_number]}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
  capture.save_to_file(filename)
  puts "✅ Successfully captured interactions!"
end

def handle_capture_error(error, capture, options)
  puts "❌ Error during execution: #{error.message}"
  puts error.backtrace.first(5)

  # Save partial capture if we have any data
  if capture.instance_variable_get(:@requests).any?
    filename = "spec/fixtures/raw_requests/pr_#{options[:pr_number]}_error_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    capture.save_to_file(filename)
  end

  exit 1
end

def capture_raw_interactions
  options = build_capture_options
  validate_capture_options(options)
  print_capture_info(options)
  capture = setup_capture_environment

  begin
    pull_request = create_pull_request_with_capture(options, capture)
    run_coverage_workflow(options, pull_request)
    save_successful_capture(capture, options)
  rescue StandardError => e
    handle_capture_error(e, capture, options)
  end
end

# Run the capture
capture_raw_interactions
