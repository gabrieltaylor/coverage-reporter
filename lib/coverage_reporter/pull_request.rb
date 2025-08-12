# frozen_string_literal: true

module CoverageReporter
  class PullRequest
    def initialize(access_token:, repo:, pr_number:)
      opts = { access_token: access_token }

      @client = Octokit::Client.new(**opts)
      @client.auto_paginate = true
      @repo = repo
      @pr_number = pr_number
    end

    def inline_comments
      client.issue_comments(repo, pr_number)
    end

    def global_comments
      client.pull_request_comments(repo, pr_number)
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

    def add_comment_on_lines(commit_id:, file_path:, start_line:, end_line:, body:, side: "RIGHT")
      payload = {
        body:       body,
        commit_id:  commit_id,
        path:       file_path,
        start_line: start_line,
        start_side: start_side,
        line:       line,
        side:       side
      }

      client.post(
        "/repos/#{repo}/pulls/#{pr_number}/comments",
        payload
      )
    end

    private

    attr_reader :client, :repo, :pr_number
  end
end
