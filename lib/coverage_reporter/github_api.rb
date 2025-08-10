# frozen_string_literal: true

module CoverageReporter
  class GitHubAPI
    GLOBAL_MARKER = "<!-- coverage-comment-marker -->"

    attr_reader :inline_comments, :global_comment_body

    def initialize(token, build_url, html_root)
      @token = token
      @build_url = build_url
      @html_root = html_root
      @inline_comments = []
      @global_comment_body = nil
    end

    def find_pr_number
      if (raw = ENV["PR_NUMBER"].to_s).match?(/\A\d+\z/)
        return raw.to_i
      end

      if (ref = ENV["GITHUB_REF"].to_s).start_with?("refs/pull/") && (m = ref.match(%r{\Arefs/pull/(\d+)/}))
        return m[1].to_i
      end

      if (bk = ENV["BUILDKITE_PULL_REQUEST"].to_s).match?(/\A\d+\z/)
        return bk.to_i
      end

      raise "Unable to infer pull request number from environment"
    end

    def coverage_index_link
      if @build_url && !@build_url.empty?
        File.join(@build_url, "coverage", "index.html")
      else
        File.join(@html_root.to_s, "index.html")
      end
    end

    def coverage_link_for(file, line)
      "#{coverage_index_link}##{file}:#{line}"
    end

    def delete_old_inline_comments(pr_number)
      @inline_comments.reject! { |c| c[:pr] == pr_number }
    end

    def comment_on_line(pr_number, file, line, body)
      @inline_comments << {
        pr:   pr_number,
        file: file,
        line: line,
        body: body
      }
    end

    def post_or_update_global_comment(_pr_number, body)
      marker_present = body.include?(GLOBAL_MARKER)
      body = "#{GLOBAL_MARKER}\n#{body}" unless marker_present
      @global_comment_body = body
    end
  end
end
