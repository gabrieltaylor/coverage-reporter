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

    def add_comment_on_lines(commit_id:, file_path:, start_line:, end_line:, body:, side: "RIGHT")
      diff = get_pull_request_diff
      actual_file_path = find_actual_file_path_in_diff(diff, file_path)
      
      # Calculate the line numbers in the diff (not file line numbers)
      diff_line_info = find_diff_line_numbers(diff, actual_file_path, start_line, end_line)
      
      payload = {
        body:       body,
        commit_id:  commit_id,
        path:       actual_file_path,
        line:       diff_line_info[:line],
        side:       diff_line_info[:side]
      }
      
      # Add start_line and start_side if we have a range (end_line > start_line)
      if end_line > start_line && diff_line_info[:start_line]
        payload[:start_line] = diff_line_info[:start_line]
        payload[:start_side] = diff_line_info[:start_side]
      end

      begin
        client.post(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          payload
        )
      rescue Octokit::Error => e
        puts "GitHub API Error: #{e.message}"
        puts "Repository: #{repo}"
        puts "PR Number: #{pr_number}"
        puts "Payload: #{payload.inspect}"
        puts "Response body: #{e.response_body}" if e.respond_to?(:response_body)
        puts "Status: #{e.status}" if e.respond_to?(:status)
        raise
      rescue => e
        puts "Unexpected error: #{e.class}: #{e.message}"
        puts "Repository: #{repo}"
        puts "PR Number: #{pr_number}"
        puts "Payload: #{payload.inspect}"
        raise
      end
    end

    private

    attr_reader :client, :repo, :pr_number

    def find_diff_line_numbers(diff, file_path, start_line, end_line)
      lines = diff.split("\n")
      current_file = nil
      in_target_file = false
      file_line_number = 0
      start_side = nil
      end_side = nil
      
      lines.each do |line|
        # Check for file header
        if line.start_with?("+++ b/")
          actual_path = line[6..-1] # Remove "+++ b/" prefix
          in_target_file = (actual_path == file_path)
          file_line_number = 0
          next
        end
        
        # If we're in the target file, process the line
        if in_target_file
          if line.start_with?("+")
            # This is an added line (RIGHT side)
            file_line_number += 1
            
            if file_line_number == start_line
              start_side = "RIGHT"
            end
            if file_line_number == end_line
              end_side = "RIGHT"
            end
          elsif line.start_with?("-")
            # This is a removed line (LEFT side)
            file_line_number += 1
            
            if file_line_number == start_line
              start_side = "LEFT"
            end
            if file_line_number == end_line
              end_side = "LEFT"
            end
          elsif line.start_with?(" ")
            # This is context - increment file line number
            file_line_number += 1
          end
        end
      end
      
      # Return the line information using file line numbers
      # For multi-line comments, line should be the last line of the range
      # For single-line comments, line should be the same as start_line
      if end_line > start_line
        # Multi-line comment: line is the last line of the range
        {
          line: end_line,
          side: end_side || start_side || "RIGHT",
          start_line: start_line,
          start_side: start_side
        }
      else
        # Single-line comment: line is the same as start_line
        {
          line: start_line,
          side: start_side || "RIGHT",
          start_line: nil,
          start_side: nil
        }
      end
    end

    def get_pull_request_diff
      @pull_request_diff ||= client.pull_request(repo, pr_number, accept: 'application/vnd.github.v3.diff')
    end

    def find_actual_file_path_in_diff(diff, file_path)
      lines = diff.split("\n")
      
      lines.each do |line|
        # Check for file header
        if line.start_with?("+++ b/")
          actual_path = line[6..-1] # Remove "+++ b/" prefix
          # Check if this matches our target file (exact match or basename match)
          if actual_path == file_path || File.basename(actual_path) == File.basename(file_path)
            return actual_path
          end
        end
      end
      
      # If no exact match found, return the original path
      file_path
    end


    def normalize_repo(repo)
      return repo if repo.include?("/") && !repo.include?("://")
      
      # If it's a full URL, extract the owner/repo part
      if repo.include?("github.com")
        match = repo.match(%r{github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$})
        return match[1] if match
      end
      
      # If it's just a repo name, we can't determine the owner
      raise ArgumentError, "Repository must be in format 'owner/repo' or a full GitHub URL"
    end
  end
end
