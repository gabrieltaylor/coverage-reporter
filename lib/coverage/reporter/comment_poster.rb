# frozen_string_literal: true

module CoverageReporter
  class CommentPoster
    def initialize(github, pr_number, stats)
      @github = github
      @pr_number = pr_number
      @stats = stats
    end

    def post_all
      post_inline_comments
      post_global_comment
    end

    private

    def post_inline_comments
      @github.delete_old_inline_comments(@pr_number)
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
          @github.comment_on_line(@pr_number, file, start, msg)
        end
      end
    end

    def post_global_comment
      summary = <<~MD
        <!-- coverage-comment-marker -->
        🧪 **Test Coverage Summary**

        ✅ **#{@stats.diff_coverage}%** of changed lines are covered.

        📊 [View full report](#{@github.coverage_index_link})
      MD

      @github.post_or_update_global_comment(@pr_number, summary)
    end
  end
end
