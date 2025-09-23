# frozen_string_literal: true

module CoverageReporter
  class GlobalCommentPoster
    GLOBAL_MARKER = "<!-- coverage-comment-marker -->"

    def initialize(pull_request:)
      @pull_request = pull_request
    end

    def call(global_comment)
      ensure_global_comment(global_comment.body)
    end

    private

    attr_reader :pull_request

    def ensure_global_comment(body)
      comments = pull_request.global_comments
      existing = comments.find { |c| c.body&.include?(GLOBAL_MARKER) }
      body_with_marker = body.include?(GLOBAL_MARKER) ? body : "#{GLOBAL_MARKER}\n#{body}"

      if existing
        pull_request.update_global_comment(id: existing.id, body: body_with_marker)
      else
        pull_request.add_global_comment(body: body_with_marker)
      end
    end
  end
end
