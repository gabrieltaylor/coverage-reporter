# frozen_string_literal: true

require "logger"
require "set"

module CoverageReporter
  class CommentPoster
    INLINE_MARKER = "<!-- coverage-inline-marker -->"
    GLOBAL_MARKER = "<!-- coverage-comment-marker -->"

    def initialize(pull_request:, analysis:, commit_sha:, logger: Logger.new($stdout))
      @pull_request = pull_request
      @analysis = analysis
      @commit_sha = commit_sha
      @logger = logger
    end

    def call
      unless latest_commit?
        @logger.info("Skipping comment posting: commit #{commit_sha} is not the latest commit (#{pull_request.latest_commit_sha})")
        return
      end

      # Track existing coverage comments to clean up unused ones later
      @existing_coverage_comments = track_existing_coverage_comments
      @updated_comment_ids = Set.new

      post_inline_comments
      post_global_comment

      # Clean up any coverage comments that weren't updated
      cleanup_unused_coverage_comments
    end

    private

    attr_reader :pull_request, :analysis, :commit_sha, :logger

    def latest_commit?
      commit_sha == pull_request.latest_commit_sha
    end

    def post_inline_comments
      # Post new comments for uncovered lines
      # The PullRequest class will handle updating existing comments instead of creating duplicates
      analysis.each do |file, ranges|
        puts "Posting inline comments for #{file}"
        ranges.each do |start_line, end_line|
          puts "Posting inline comment for #{file}: #{start_line}–#{end_line}"
          post_inline_comment(file: file, start_line: start_line, end_line: end_line)
        end
      end
    end

    def inline_message(start_line, end_line)
      if start_line == end_line
        "❌ Line #{start_line} is not covered by tests."
      else
        "❌ Lines #{start_line}–#{end_line} are not covered by tests."
      end
    end

    def build_inline_body(file:, start_line:, message:)
      "#{INLINE_MARKER}\n#{message}\n\n_File: #{file}, line #{start_line}_\n_Commit: #{commit_sha}_"
    end

    def post_inline_comment(file:, start_line:, end_line:)
      message = inline_message(start_line, end_line)
      body = build_inline_body(file: file, start_line: start_line, message: message)

      # Check if there's an existing comment for this line range
      existing_comment = pull_request.find_existing_inline_comment(file, start_line, end_line)

      if existing_comment
        # Update existing comment and track it
        pull_request.update_inline_comment(id: existing_comment.id, body: body)
        @updated_comment_ids.add(existing_comment.id)
      else
        # Create new comment
        pull_request.add_comment_on_lines(
          commit_id:  commit_sha,
          file_path:  file,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )
      end
    end

    def post_global_comment
      coverage_percentage = calculate_coverage_percentage
      summary = <<~MD
        #{GLOBAL_MARKER}
        🧪 **Test Coverage Summary**

        ✅ **#{coverage_percentage}%** of changed lines are covered.

        _Commit: #{commit_sha}_
      MD

      ensure_global_comment(summary)
    end

    def calculate_coverage_percentage
      # Since we only have uncovered ranges, we can't calculate exact coverage percentage
      # without knowing the total changed lines. For now, return a placeholder.
      # This could be enhanced to accept total changed lines as a parameter.
      "N/A"
    end

    def ensure_global_comment(body)
      comments = @pull_request.global_comments
      existing = comments.find { |c| c.body&.include?(GLOBAL_MARKER) }
      body_with_marker = body.include?(GLOBAL_MARKER) ? body : "#{GLOBAL_MARKER}\n#{body}"
      if existing
        @pull_request.update_global_comment(id: existing.id, body: body_with_marker)
      else
        @pull_request.add_global_comment(body: body_with_marker)
      end
    end

    def track_existing_coverage_comments
      # Get all existing coverage comments (both inline and global)
      inline_comments = pull_request.inline_comments.select do |comment|
        comment.body&.include?(INLINE_MARKER)
      end

      global_comments = pull_request.global_comments.select do |comment|
        comment.body&.include?(GLOBAL_MARKER)
      end

      # Return a hash with comment ID as key and comment object as value
      all_comments = {}
      inline_comments.each { |comment| all_comments[comment.id] = comment }
      global_comments.each { |comment| all_comments[comment.id] = comment }

      all_comments
    end

    def cleanup_unused_coverage_comments
      # Find comments that weren't updated during this run
      unused_comment_ids = @existing_coverage_comments.keys - @updated_comment_ids.to_a

      unused_comment_ids.each do |comment_id|
        comment = @existing_coverage_comments[comment_id]
        logger.info("Removing unused coverage comment: #{comment_id} (#{comment.path || 'global'})")
        pull_request.delete_inline_comment(comment_id)
      end
    end
  end
end
