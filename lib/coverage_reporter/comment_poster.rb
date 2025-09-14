# frozen_string_literal: true

require "logger"

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

      post_inline_comments
      post_global_comment
    end

    private

    attr_reader :pull_request, :analysis, :commit_sha, :logger

    def latest_commit?
      commit_sha == pull_request.latest_commit_sha
    end

    def post_inline_comments
      # First, clean up old coverage comments for files that now have coverage
      cleanup_old_coverage_comments

      # Then post new comments for uncovered lines
      analysis.uncovered_by_file.each do |file, lines|
        contiguous_chunks(lines).each do |start_line, end_line|
          post_inline_comment(file: file, start_line: start_line, end_line: end_line)
        end
      end
    end

    def contiguous_chunks(lines)
      lines
        .sort
        .chunk_while { |i, j| j == i + 1 }
        .map { |chunk| [chunk.first, chunk.last] }
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
      pull_request.add_comment_on_lines(
        commit_id:  commit_sha,
        file_path:  file,
        start_line: start_line,
        end_line:   end_line,
        body:       body
      )
    end

    def post_global_comment
      summary = <<~MD
        #{GLOBAL_MARKER}
        🧪 **Test Coverage Summary**

        ✅ **#{analysis.diff_coverage}%** of changed lines are covered.

        _Commit: #{commit_sha}_
      MD

      ensure_global_comment(summary)
    end

    def cleanup_old_coverage_comments
      # Get all files that have coverage (either covered or uncovered)
      all_files = analysis.uncovered_by_file.keys

      # For each file, delete any existing coverage comments
      # since we're about to post new ones for uncovered lines only
      all_files.each do |file|
        pull_request.delete_coverage_comments_for_file(file)
      end
    end

    def ensure_global_comment(body)
      comments = @pull_request.global_comments
      existing = comments.find { |c| c.body&.include?(GLOBAL_MARKER) }
      body_with_marker = body.include?(GLOBAL_MARKER) ? body : "#{GLOBAL_MARKER}\n#{body}"
      if existing
        @pull_request.update_comment(id: existing.id, body: body_with_marker)
      else
        @pull_request.add_comment(body: body_with_marker)
      end
    end
  end
end
