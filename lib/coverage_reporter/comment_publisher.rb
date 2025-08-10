# frozen_string_literal: true

module CoverageReporter
  class CommentPublisher
    def initialize(github:, chunker:, formatter:, repo: nil)
      @github = github
      @chunker = chunker
      @formatter = formatter
      @repo = repo
    end

    INLINE_MARKER = "<!-- coverage-inline-marker -->"
    GLOBAL_MARKER_FALLBACK = "<!-- coverage-comment-marker -->"

    def publish_inline(pr_number:, uncovered_by_file:)
      if octokit_mode?
        delete_old_inline_comments_octokit(pr_number)
      else
        @github.delete_old_inline_comments(pr_number)
      end

      uncovered_by_file.each do |file, lines|
        @chunker.chunks(lines).each do |chunk|
          message = @formatter.inline_chunk_message(file: file, chunk: chunk)
          if octokit_mode?
            # We cannot easily create true "inline code review" comments without diff
            # position data, so we fall back to normal PR issue comments that still
            # clearly reference the file and line. We include an inline marker so we
            # can safely delete/refresh them later.
            body = "#{INLINE_MARKER}\n#{message}\n\n_File: #{file}, line #{chunk.first}_"
            @github.add_comment(@repo, pr_number, body)
          else
            @github.comment_on_line(pr_number, file, chunk.first, message)
          end
        end
      end
    end

    def publish_global(pr_number:, diff_coverage:)
      body = @formatter.global_summary(diff_coverage: diff_coverage)
      if octokit_mode?
        ensure_global_comment_octokit(pr_number, body)
      else
        @github.post_or_update_global_comment(pr_number, body)
      end
    end

    private

    def octokit_mode?
      defined?(Octokit) && @github.is_a?(Octokit::Client) && @repo
    end

    # Octokit (issue comment) helpers

    def delete_old_inline_comments_octokit(pr_number)
      comments = @github.issue_comments(@repo, pr_number)
      comments.select { |c| c.body&.include?(INLINE_MARKER) }.each do |comment|
        @github.delete_comment(@repo, comment.id)
      end
    end

    def ensure_global_comment_octokit(pr_number, body)
      marker = global_marker_string
      comments = @github.issue_comments(@repo, pr_number)
      existing = comments.find { |c| c.body&.include?(marker) }
      body_with_marker = body.include?(marker) ? body : "#{marker}\n#{body}"
      if existing
        @github.update_comment(@repo, existing.id, body_with_marker)
      else
        @github.add_comment(@repo, pr_number, body_with_marker)
      end
    end

    def global_marker_string
      if defined?(CoverageReporter::GitHubAPI::GLOBAL_MARKER)
        CoverageReporter::GitHubAPI::GLOBAL_MARKER
      else
        GLOBAL_MARKER_FALLBACK
      end
    end
  end
end
