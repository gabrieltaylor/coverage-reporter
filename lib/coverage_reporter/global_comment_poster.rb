# frozen_string_literal: true

module CoverageReporter
  class GlobalCommentPoster

    def initialize(pull_request:, global_comment:)
      @pull_request = pull_request
      @global_comment = global_comment
    end

    def call
      ensure_global_comment
    end

    private

    attr_reader :pull_request, :global_comment

    def ensure_global_comment
      comments = pull_request.global_comments
      existing = comments.find { |c| c.body&.include?(GLOBAL_COMMENT_MARKER) }

      if existing
        pull_request.update_global_comment(id: existing.id, body: global_comment.body)
      else
        pull_request.add_global_comment(body: global_comment.body)
      end
    end
  end
end
