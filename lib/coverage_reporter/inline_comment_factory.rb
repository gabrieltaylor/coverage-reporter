# frozen_string_literal: true

module CoverageReporter
  class InlineCommentFactory

    def initialize(commit_sha:, intersection:)
      @commit_sha = commit_sha
      @intersection = intersection
    end

    def call
      comments = []

      @intersection.each do |file, ranges|
        ranges.each do |start_line, end_line|
          message = build_message(start_line, end_line)
          body = build_body(file: file, start_line: start_line, message: message)

          comments << InlineComment.new(
            file:       file,
            start_line: start_line,
            end_line:   end_line,
            message:    message,
            body:       body
          )
        end
      end

      comments
    end

    private

    attr_reader :commit_sha, :intersection

    def build_message(start_line, end_line)
      if start_line == end_line
        "❌ Line #{start_line} is not covered by tests."
      else
        "❌ Lines #{start_line}–#{end_line} are not covered by tests."
      end
    end

    def build_body(file:, start_line:, message:)
      "#{INLINE_COMMENT_MARKER}\n#{message}\n\n_File: #{file}, line #{start_line}_\n_Commit: #{commit_sha}_"
    end
  end
end
