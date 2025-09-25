# frozen_string_literal: true

module CoverageReporter
  class PullRequest
    def initialize(github_token:, repo:, pr_number:)
      opts = { access_token: github_token }

      @client = ::Octokit::Client.new(**opts)
      @client.auto_paginate = true
      @repo = normalize_repo(repo)
      @pr_number = pr_number
    end

    def latest_commit_sha
      @latest_commit_sha ||= client.pull_request(repo, pr_number).head.sha
    end

    # get global comments
    def global_comments
      client.issue_comments(repo, pr_number)
    end

    # add global comment
    def add_global_comment(body:)
      client.add_comment(repo, pr_number, body)
    end

    # update global comment
    def update_global_comment(id:, body:)
      client.update_comment(repo, id, body)
    end

    # delete global comment
    def delete_global_comment(id)
      client.delete_comment(repo, id)
    end

    # get inline comments
    def inline_comments
      client.pull_request_comments(repo, pr_number)
    end

    # update inline comment
    def update_inline_comment(id:, body:)
      client.update_pull_request_comment(repo, id, body)
    end

    # delete inline comment
    def delete_inline_comment(id)
      client.delete_pull_request_comment(repo, id)
    end

    def add_comment_on_lines(commit_id:, file_path:, start_line:, end_line:, body:)
      existing_comment = find_existing_inline_comment(file_path, start_line, end_line)

      if existing_comment
        update_inline_comment(id: existing_comment.id, body: body)
      else
        diff_line_info = find_diff_line_numbers(diff, file_path, start_line, end_line)
        payload = build_comment_payload(body, commit_id, file_path, diff_line_info, start_line, end_line)
        create_comment_with_error_handling(payload)
      end
    end

    def delete_coverage_comments_for_file(file_path)
      coverage_comments = inline_comments.select do |comment|
        comment.body&.include?("<!-- coverage-inline-marker -->") &&
          comment.path == file_path
      end

      coverage_comments.each { |comment| delete_inline_comment(comment.id) }
    end

    def find_existing_inline_comment(file_path, start_line, end_line)
      inline_comments.find do |comment|
        coverage_comment_for_file?(comment, file_path) &&
          comment_matches_line_range?(comment, start_line, end_line)
      end
    end

    def diff
      @diff ||= client.pull_request(repo, pr_number, accept: "application/vnd.github.v3.diff")
    end

    private

    attr_reader :client, :repo, :pr_number

    def logger
      CoverageReporter.logger
    end

    def normalize_repo(repo)
      return repo if repo.include?("/") && !repo.include?("://")
      return extract_github_repo(repo) if repo.include?("github.com")

      raise ArgumentError, "Repository must be in format 'owner/repo' or a full GitHub URL"
    end

    def build_comment_payload(body, commit_id, file_path, _diff_line_info, start_line, end_line)
      actual_file_path = find_actual_file_path_in_diff(diff, file_path)
      payload = {
        body:      body,
        commit_id: commit_id,
        path:      actual_file_path,
        side:      "RIGHT"
      }

      if end_line > start_line && start_line
        payload[:line] = end_line
        payload[:start_line] = start_line
      elsif end_line == start_line
        payload[:line] = end_line
      end

      payload
    end

    def create_comment_with_error_handling(payload)
      client.post("/repos/#{repo}/pulls/#{pr_number}/comments", payload)
    rescue Octokit::Error => e
      handle_github_api_error(e, payload)
    end

    def handle_github_api_error(error, payload)
      logger.error("GitHub API Error: #{error.message}")
      logger.error("Payload: #{payload.inspect}")
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
        comment.line == start_line && (comment.start_line.nil? || comment.start_line == start_line)
      end
    end

    def extract_github_repo(repo)
      match = repo.match(%r{github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$})
      match[1] if match
    end

    def find_actual_file_path_in_diff(diff_text, file_path)
      return file_path if diff_text.nil? || diff_text.empty?

      # Try exact match first
      return file_path if diff_text.include?("diff --git a/#{file_path}")

      # Try basename match
      basename = File.basename(file_path)
      diff_text.scan(%r{diff --git a/([^\s]+)}) do |match|
        return match[0] if File.basename(match[0]) == basename
      end

      file_path
    end

    def find_diff_line_numbers(diff_text, file_path, start_line, end_line)
      find_actual_file_path_in_diff(diff_text, file_path)

      # For now, return basic structure - this could be enhanced to parse actual diff
      # and determine the correct side and line numbers
      result = {
        side:       "RIGHT",
        start_side: "RIGHT"
      }

      result[:line] = end_line
      result[:start_line] = start_line if end_line > start_line

      result
    end
  end
end
