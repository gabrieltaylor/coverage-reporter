# frozen_string_literal: true

require "set"

module CoverageReporter
  class InlineCommentPoster
    def initialize(pull_request:, commit_sha:, inline_comments:)
      @pull_request = pull_request
      @commit_sha = commit_sha
      @updated_comment_ids = Set.new
      @inline_comments = inline_comments
      @existing_coverage_comments = {}
    end

    def call
      retrieve_existing_coverage_comments

      inline_comments.each do |comment|
        logger.info("Posting inline comment for #{comment.path}: #{comment.start_line}–#{comment.line}")
        post_comment(comment)
      end

      cleanup_stale_comments
    end

    private

    attr_reader :pull_request, :commit_sha, :updated_comment_ids, :inline_comments, :existing_coverage_comments

    def logger
      CoverageReporter.logger
    end

    def retrieve_existing_coverage_comments
      logger.debug("Recording existing coverage comments")
      @existing_coverage_comments = pull_request
        .inline_comments
        .filter { |comment| coverage_comment?(comment) }
        .to_h do |comment|
          logger.debug("Found existing coverage comment: #{comment.id} for #{comment.path}:#{comment.start_line}-#{comment.line}")
          [comment.id, comment]
        end
    end

    def cleanup_stale_comments
      comment_ids_to_delete = existing_coverage_comments.keys - updated_comment_ids.to_a

      if comment_ids_to_delete.any?
        logger.debug("Cleaning up #{comment_ids_to_delete.size} unused coverage comments")

        comment_ids_to_delete.each do |comment_id|
          logger.info("Deleting stale coverage comment: #{comment_id}")
          pull_request.delete_inline_comment(comment_id)
        end
      else
        logger.debug("No stale coverage comments to clean up")
      end
    end

    def coverage_comment?(comment)
      comment.body&.include?(INLINE_COMMENT_MARKER)
    end

    def post_comment(comment)
      existing_comment = existing_comment_for_path_and_lines(comment.path, comment.start_line, comment.line)

      if existing_comment
        pull_request.update_inline_comment(id: existing_comment.id, body: comment.body)
        updated_comment_ids.add(existing_comment.id)
      else
        pull_request.add_comment_on_lines(
          commit_id:  commit_sha,
          path:       comment.path,
          start_line: comment.start_line,
          line:       comment.line,
          body:       comment.body
        )
      end
    end

    def existing_comment_for_path_and_lines(path, start_line, line)
      existing_coverage_comments.values.find do |comment|
        comment.path == path && comment.start_line == start_line && comment.line == line
      end
    end
  end
end
