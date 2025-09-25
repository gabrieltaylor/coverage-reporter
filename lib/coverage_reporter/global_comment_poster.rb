# frozen_string_literal: true

module CoverageReporter
  class GlobalCommentPoster
    GLOBAL_MARKER = "<!-- coverage-comment-marker -->"

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
      existing = comments.find { |c| c.body&.include?(GLOBAL_MARKER) }
      body_with_marker = global_comment.body.include?(GLOBAL_MARKER) ? global_comment.body : "#{GLOBAL_MARKER}\n#{global_comment.body}"

      if existing
        pull_request.update_global_comment(id: existing.id, body: body_with_marker)
      else
        pull_request.add_global_comment(body: body_with_marker)
      end
    end
  end
end
