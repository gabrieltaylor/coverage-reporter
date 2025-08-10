# frozen_string_literal: true

module CoverageReporter
  class CommentPublisher
    def initialize(github:, chunker:, formatter:)
      @github = github
      @chunker = chunker
      @formatter = formatter
    end

    def publish_inline(pr_number:, uncovered_by_file:)
      @github.delete_old_inline_comments(pr_number)

      uncovered_by_file.each do |file, lines|
        @chunker.chunks(lines).each do |chunk|
          message = @formatter.inline_chunk_message(file: file, chunk: chunk)
          @github.comment_on_line(pr_number, file, chunk.first, message)
        end
      end
    end

    def publish_global(pr_number:, diff_coverage:)
      body = @formatter.global_summary(diff_coverage: diff_coverage)
      @github.post_or_update_global_comment(pr_number, body)
    end
  end
end
