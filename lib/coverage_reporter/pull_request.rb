# frozen_string_literal: true

require "base64"

module CoverageReporter
  class PullRequest
    def initialize(github_token:, repo:, pr_number:)
      opts = { access_token: github_token }

      @client = ::Octokit::Client.new(**opts)
      @client.auto_paginate = true
      @repo = repo
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

    def add_comment_on_lines(commit_id:, path:, start_line:, line:, body:)
      payload = build_comment_payload(body:, commit_id:, path:, start_line:, line:)
      create_comment_with_error_handling(payload)
    end

    def diff
      @diff ||= client.pull_request(repo, pr_number, accept: "application/vnd.github.v3.diff")
    end

    def file_content(path:, commit_sha:)
      content = client.contents(repo, path: path, ref: commit_sha)
      # GitHub API returns file content as base64-encoded string
      if content.encoding == "base64" && content.content
        Base64.decode64(content.content)
      elsif content.content
        content.content
      end
    rescue Octokit::NotFound, Octokit::Error
      nil
    end

    private

    attr_reader :client, :repo, :pr_number

    def logger
      CoverageReporter.logger
    end

    def build_comment_payload(body:, commit_id:, path:, start_line:, line:)
      payload = {
        body:      body,
        commit_id: commit_id,
        path:      path,
        side:      "RIGHT"
      }

      if start_line && line > start_line
        payload[:line] = line
        payload[:start_line] = start_line
      elsif start_line == line
        payload[:line] = line
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
  end
end
