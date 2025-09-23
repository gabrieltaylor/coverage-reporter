# frozen_string_literal: true

require "set"

module CoverageReporter
  class InlineCommentPoster
    def initialize(pull_request:, commit_sha:, inline_comments:)
      @pull_request = pull_request
      @commit_sha = commit_sha
      @updated_comment_ids = Set.new
      @inline_comments = inline_comments
    end

    def call
      inline_comments.each do |comment|
        logger.debug("Posting inline comment for #{comment.file}: #{comment.start_line}–#{comment.end_line}")
        post_comment(comment)
      end

      @updated_comment_ids
    end

    private

    attr_reader :pull_request, :commit_sha, :updated_comment_ids, :inline_comments

    def logger
      CoverageReporter.logger
    end

    def post_comment(comment)
      existing_comment = pull_request.find_existing_inline_comment(comment.file, comment.start_line, comment.end_line)

      if existing_comment
        pull_request.update_inline_comment(id: existing_comment.id, body: comment.body)
        @updated_comment_ids.add(existing_comment.id)
      else
        pull_request.add_comment_on_lines(
          commit_id:  commit_sha,
          file_path:  comment.file,
          start_line: comment.start_line,
          end_line:   comment.end_line,
          body:       comment.body
        )
      end
    end
  end
end
