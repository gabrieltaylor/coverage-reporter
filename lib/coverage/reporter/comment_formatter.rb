# frozen_string_literal: true

module CoverageReporter
  class CommentFormatter
    def initialize(github:)
      @github = github
    end

    def inline_chunk_message(file:, chunk:)
      start = chunk.first
      finish = chunk.last
      header =
        if chunk.size == 1
          "❌ Line #{start} is not covered by tests."
        else
          "❌ Lines #{start}–#{finish} are not covered by tests."
        end
      link = @github.coverage_link_for(file, start)
      "#{header}

📊 [View coverage](#{link})"
    end

    def global_summary(diff_coverage:)
      <<~MD
        <!-- coverage-comment-marker -->
        🧪 **Test Coverage Summary**

        ✅ **#{diff_coverage}%** of changed lines are covered.

        📊 [View full report](#{@github.coverage_index_link})
      MD
    end
  end
end
