# frozen_string_literal: true

module CoverageReporter
  class CommentPoster
    INLINE_MARKER = "<!-- coverage-inline-marker -->"
    GLOBAL_MARKER = "<!-- coverage-comment-marker -->"

    def initialize(github, pr_number, stats, repo:)
      @github = github
      @pr_number = pr_number
      @stats = stats
      @repo = repo
    end

    def post_all
      post_inline_comments
      post_global_comment
    end

    private

    def post_inline_comments
      delete_old_inline_comments_octokit

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
          @github.add_comment(@repo, @pr_number, body)
        end
      end
    end

    def post_global_comment
      summary = <<~MD
        #{GLOBAL_MARKER}
        🧪 **Test Coverage Summary**

        ✅ **#{@stats.diff_coverage}%** of changed lines are covered.

        📊 [View full report](#{@github.coverage_index_link})
      MD

      ensure_global_comment_octokit(summary)
    end

    # --- Octokit helpers ---

    def delete_old_inline_comments_octokit
      comments = @github.issue_comments(@repo, @pr_number)
      comments.select { |c| c.body&.include?(INLINE_MARKER) }.each do |comment|
        @github.delete_comment(@repo, comment.id)
      end
    end

    def ensure_global_comment_octokit(body)
      comments = @github.issue_comments(@repo, @pr_number)
      existing = comments.find { |c| c.body&.include?(GLOBAL_MARKER) }
      body_with_marker = body.include?(GLOBAL_MARKER) ? body : "#{GLOBAL_MARKER}\n#{body}"
      if existing
        @github.update_comment(@repo, existing.id, body_with_marker)
      else
        @github.add_comment(@repo, @pr_number, body_with_marker)
      end
    end
  end
end
