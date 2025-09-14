# frozen_string_literal: true

module CoverageReporter
  class PullRequest
    def initialize(github_token:, repo:, pr_number:)
      raise ArgumentError, "GitHub token is required" if github_token.nil? || github_token.empty?
      raise ArgumentError, "Repository is required" if repo.nil? || repo.empty?
      raise ArgumentError, "PR number is required" if pr_number.nil? || pr_number.empty?

      opts = { access_token: github_token }

      @client = ::Octokit::Client.new(**opts)
      @client.auto_paginate = true
      @repo = normalize_repo(repo)
      @pr_number = pr_number
    end

    def inline_comments
      client.issue_comments(repo, pr_number)
    end

    def global_comments
      client.pull_request_comments(repo, pr_number)
    end

    def latest_commit_sha
      @latest_commit_sha ||= client.pull_request(repo, pr_number).head.sha
    end

    def add_comment(body:)
      client.post(
        "/repos/#{repo}/pulls/#{pr_number}/comments",
        body: body
      )
    end

    def update_comment(id:, body:)
      client.patch(
        "/repos/#{repo}/pulls/comments/#{id}",
        body: body
      )
    end

    def delete_comment(id)
      client.delete("/repos/#{repo}/pulls/comments/#{id}")
    end

    def add_comment_on_lines(commit_id:, file_path:, start_line:, end_line:, body:)
      diff = pull_request_diff
      actual_file_path = find_actual_file_path_in_diff(diff, file_path)
      diff_line_info = find_diff_line_numbers(diff, actual_file_path, start_line, end_line)
      existing_comment = find_existing_inline_comment(actual_file_path, start_line, end_line)

      if existing_comment
        update_comment(id: existing_comment.id, body: body)
      else
        payload = build_comment_payload(body, commit_id, actual_file_path, diff_line_info, start_line, end_line)
        create_comment_with_error_handling(payload)
      end
    end

    def delete_coverage_comments_for_file(file_path)
      coverage_comments = inline_comments.select do |comment|
        comment.body&.include?("<!-- coverage-inline-marker -->") &&
          comment.path == file_path
      end

      coverage_comments.each { |comment| delete_comment(comment.id) }
    end

    private

    attr_reader :client, :repo, :pr_number

    def find_diff_line_numbers(diff, file_path, start_line, end_line)
      state = DiffParserState.new(file_path, start_line, end_line)
      diff.split("\n").each { |line| state.process_line(line) }
      state.result
    end

    def pull_request_diff
      @pull_request_diff ||= client.pull_request(repo, pr_number, accept: "application/vnd.github.v3.diff")
    end

    def find_actual_file_path_in_diff(diff, file_path)
      lines = diff.split("\n")

      lines.each do |line|
        # Check for file header
        next unless line.start_with?("+++ b/")

        actual_path = line[6..] # Remove "+++ b/" prefix
        # Check if this matches our target file (exact match or basename match)
        return actual_path if actual_path == file_path || File.basename(actual_path) == File.basename(file_path)
      end

      # If no exact match found, return the original path
      file_path
    end

    def find_existing_inline_comment(file_path, start_line, end_line)
      inline_comments.find do |comment|
        coverage_comment_for_file?(comment, file_path) &&
          comment_matches_line_range?(comment, start_line, end_line)
      end
    end

    def normalize_repo(repo)
      return repo if repo.include?("/") && !repo.include?("://")
      return extract_github_repo(repo) if repo.include?("github.com")

      raise ArgumentError, "Repository must be in format 'owner/repo' or a full GitHub URL"
    end

    def build_comment_payload(body, commit_id, file_path, diff_line_info, start_line, end_line)
      payload = {
        body:      body,
        commit_id: commit_id,
        path:      file_path,
        line:      diff_line_info[:line],
        side:      diff_line_info[:side]
      }

      if end_line > start_line && diff_line_info[:start_line]
        payload[:start_line] = diff_line_info[:start_line]
        payload[:start_side] = diff_line_info[:start_side] || "RIGHT"
      elsif end_line == start_line
        payload[:line] = diff_line_info[:line]
        # Don't include start_line when it's the same as line
      end

      payload
    end

    def create_comment_with_error_handling(payload)
      client.post("/repos/#{repo}/pulls/#{pr_number}/comments", payload)
    rescue Octokit::Error => e
      handle_github_api_error(e, payload)
    rescue StandardError => e
      handle_unexpected_error(e, payload)
    end

    def handle_github_api_error(error, payload)
      puts "GitHub API Error: #{error.message}"
      puts "Repository: #{repo}"
      puts "PR Number: #{pr_number}"
      puts "Payload: #{payload.inspect}"
      puts "Response body: #{error.response_body}" if error.respond_to?(:response_body)
      puts "Status: #{error.status}" if error.respond_to?(:status)
      raise
    end

    def handle_unexpected_error(error, payload)
      puts "Unexpected error: #{error.class}: #{error.message}"
      puts "Repository: #{repo}"
      puts "PR Number: #{pr_number}"
      puts "Payload: #{payload.inspect}"
      raise
    end

    def coverage_comment_for_file?(comment, file_path)
      comment.body&.include?("<!-- coverage-inline-marker -->") &&
        comment.path == file_path
    end

    def comment_matches_line_range?(comment, start_line, end_line)
      if end_line > start_line
        comment.line == end_line && comment.start_line == start_line
      else
        comment.line == start_line && comment.start_line == start_line
      end
    end

    def extract_github_repo(repo)
      match = repo.match(%r{github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$})
      match[1] if match
    end
  end

  # Helper class to parse diff and find line numbers
  class DiffParserState
    def initialize(file_path, start_line, end_line)
      @file_path = file_path
      @start_line = start_line
      @end_line = end_line
      @in_target_file = false
      @file_line_number = 0
      @start_side = nil
      @end_side = nil
    end

    def process_line(line)
      if file_header?(line)
        handle_file_header(line)
      elsif @in_target_file
        process_diff_line(line)
      end
    end

    def result
      if @end_line > @start_line
        build_multi_line_result
      else
        build_single_line_result
      end
    end

    private

    def file_header?(line)
      line.start_with?("+++ b/")
    end

    def handle_file_header(line)
      actual_path = line[6..] # Remove "+++ b/" prefix
      @in_target_file = (actual_path == @file_path)
      @file_line_number = 0
    end

    def process_diff_line(line)
      if line.start_with?("+")
        process_added_line
      elsif line.start_with?("-")
        process_removed_line
      elsif line.start_with?(" ")
        @file_line_number += 1
      end
    end

    def process_added_line
      @file_line_number += 1
      @start_side = "RIGHT" if @file_line_number == @start_line
      @end_side = "RIGHT" if @file_line_number == @end_line
    end

    def process_removed_line
      @file_line_number += 1
      @start_side = "LEFT" if @file_line_number == @start_line
      @end_side = "LEFT" if @file_line_number == @end_line
    end

    def build_multi_line_result
      {
        line:       @end_line,
        side:       @end_side || @start_side || "RIGHT",
        start_line: @start_line,
        start_side: @start_side || "RIGHT"
      }
    end

    def build_single_line_result
      {
        line:       @start_line,
        side:       @start_side || "RIGHT",
        start_line: nil,
        start_side: @start_side || "RIGHT"
      }
    end
  end
end
