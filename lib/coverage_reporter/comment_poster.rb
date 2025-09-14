# frozen_string_literal: true

require 'logger'

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
      delete_old_inline_comments

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
      "#{INLINE_MARKER}\n#{message}\n\n_File: #{file}, line #{start_line}_"
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
      MD

      ensure_global_comment(summary)
    end

    def delete_old_inline_comments
      comments = pull_request.inline_comments
      comments.select { |c| c.body&.include?(INLINE_MARKER) }.each do |comment|
        pull_request.delete_comment(comment.id)
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
