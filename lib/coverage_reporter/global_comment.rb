# frozen_string_literal: true

module CoverageReporter
  class GlobalComment
    def initialize(coverage_percentage:, commit_sha:, report_url: nil, intersections: {})
      @coverage_percentage = coverage_percentage
      @commit_sha = commit_sha
      @report_url = report_url
      @intersections = intersections
      @body = build_body
    end

    attr_reader :coverage_percentage, :commit_sha, :report_url, :intersections, :body

    private

    def build_body
      body = <<~MD
        <!-- coverage-comment-marker -->
        **Test Coverage Summary**

        #{coverage_percentage < 100 ? '❌' : '✅'} **#{coverage_percentage}%** of relevant modified lines are covered.

        [View full report](#{report_url})

        _Commit: #{commit_sha}_
      MD

      body += "\n\n#{coverage_summary_section}" if intersections.any?

      body
    end

    def coverage_summary_section
      <<~MD
        **Coverage Summary**

        | File | Uncovered Lines |
        |------|----------------|
        #{coverage_summary_table_rows}
      MD
    end

    def coverage_summary_table_rows
      intersections.map do |file, ranges|
        formatted_ranges = ranges.map { |range| format_range(range) }.join(", ")
        "| `#{file}` | #{formatted_ranges} |"
      end.join("\n")
    end

    def format_range(range)
      start_line, end_line = range
      if start_line == end_line
        start_line.to_s
      else
        "#{start_line}-#{end_line}"
      end
    end
  end
end
