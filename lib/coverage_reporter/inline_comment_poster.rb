# frozen_string_literal: true

require "set"

module CoverageReporter
  class InlineCommentPoster
    def initialize(pull_request:, commit_sha:, inline_comments:)
      @pull_request = pull_request
      @commit_sha = commit_sha
      @updated_comment_ids = Set.new
      @inline_comments = inline_comments
      @existing_coverage_comment_ids = Set.new
    end

    def call
      # Record existing coverage comments before posting new ones
      record_existing_coverage_comments

      # Post or update comments
      inline_comments.each do |comment|
        logger.debug("Posting inline comment for #{comment.file}: #{comment.start_line}–#{comment.end_line}")
        post_comment(comment)
      end

      # Clean up any existing coverage comments that weren't updated
      cleanup_stale_comments

      @updated_comment_ids
    end

    private

    attr_reader :pull_request, :commit_sha, :updated_comment_ids, :inline_comments, :existing_coverage_comment_ids

    def logger
      CoverageReporter.logger
    end

    def record_existing_coverage_comments
      logger.debug("Recording existing coverage comments")
      
      pull_request.inline_comments.each do |comment|
        if coverage_comment?(comment)
          @existing_coverage_comment_ids.add(comment.id)
          logger.debug("Found existing coverage comment: #{comment.id} for #{comment.path}:#{comment.line}")
        end
      end
    end

    def cleanup_stale_comments
      comments_to_delete = @existing_coverage_comment_ids - @updated_comment_ids
      
      if comments_to_delete.any?
        logger.debug("Cleaning up #{comments_to_delete.size} unused coverage comments")
        
        comments_to_delete.each do |comment_id|
          logger.debug("Deleting unused coverage comment: #{comment_id}")
          pull_request.delete_inline_comment(comment_id)
        end
      else
        logger.debug("No unused coverage comments to clean up")
      end
    end

    def coverage_comment?(comment)
      comment.body&.include?(INLINE_COMMENT_MARKER)
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
