# frozen_string_literal: true

module CoverageReporter
  class InlineCommentFactory
    def initialize(commit_sha:, intersection:)
      @commit_sha = commit_sha
      @intersection = intersection
    end

    def call
      comments = []

      @intersection.each do |path, ranges|
        ranges.each do |start_line, line|
          body = build_body(path:, start_line:, line:)

          comments << InlineComment.new(
            path:       path,
            start_line: start_line,
            line:       line,
            body:       body
          )
        end
      end

      comments
    end

    private

    attr_reader :commit_sha, :intersection

    def build_body(path:, start_line:, line:)
      message = build_message(start_line, line)
      "#{INLINE_COMMENT_MARKER}\n#{message}\n\n_File: #{path}, line #{start_line}_\n_Commit: #{commit_sha}_"
    end

    def build_message(start_line, line)
      if start_line == line
        "❌ Line #{start_line} is not covered by tests."
      else
        "❌ Lines #{start_line}–#{line} are not covered by tests."
      end
    end
  end
end
