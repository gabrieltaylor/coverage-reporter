# frozen_string_literal: true

module CoverageReporter
  class CommentPoster
    INLINE_MARKER = "<!-- coverage-inline-marker -->"
    GLOBAL_MARKER = "<!-- coverage-comment-marker -->"

    def initialize(pull_request:, stats:)
      @pull_request = pull_request
      @stats = stats
    end

    def call
      post_inline_comments
      post_global_comment
    end

    private

    def post_inline_comments
      delete_old_inline_comments

      @stats.uncovered.each do |file, lines|
        lines.sort.chunk_while { |i, j| j == i + 1 }.each do |chunk|
          start = chunk.first
            stop = chunk.last
          msg =
            if chunk.size == 1
              "❌ Line #{start} is not covered by tests."
            else
              "❌ Lines #{start}–#{stop} are not covered by tests."
            end
          msg += "\n\n📊 [View coverage](#{@github.coverage_link_for(file, start)})"

          body = "#{INLINE_MARKER}\n#{msg}\n\n_File: #{file}, line #{start}_"
          @pull_request.add_comment_on_lines(commit_id: @stats.commit_sha, file_path: file, start_line: start, end_line: stop, body: body)
        end
      end
    end

    def post_global_comment
      summary = <<~MD
        #{GLOBAL_MARKER}
        🧪 **Test Coverage Summary**

        ✅ **#{@stats.diff_coverage}%** of changed lines are covered.
      MD

      ensure_global_comment(summary)
    end

    def delete_old_inline_comments
      comments = @pull_request.inline_comments
      comments.select { |c| c.body&.include?(INLINE_MARKER) }.each do |comment|
        @pull_request.delete_comment(comment.id)
      end
    end

    def ensure_global_comment(body)
      comments = @pull_request.global_comments
      existing = comments.find { |c| c.body&.include?(GLOBAL_MARKER) }
      body_with_marker = body.include?(GLOBAL_MARKER) ? body : "#{GLOBAL_MARKER}\n#{body}"
      if existing
        @pull_request.update_comment(existing.id, body_with_marker)
      else
        @pull_request.add_comment(body_with_marker)
      end
    end
  end
end
