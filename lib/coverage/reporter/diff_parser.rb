# frozen_string_literal: true

require "open3"
require "shellwords"

module CoverageReporter
  class DiffParser
    HUNK_HEADER = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/

    def initialize(base_ref)
      @base_ref = base_ref
    end

    def fetch_diff
      output = run_git_diff
      return {} unless output

      parse_diff(output)
    rescue StandardError
      {}
    end

    private

    def run_git_diff
      ref = Shellwords.escape(@base_ref.to_s)
      cmd = "git diff --unified=0 #{ref}...HEAD --diff-filter=AM --no-color"
      stdout, status = Open3.capture2e(cmd)
      return nil unless status.success?

      stdout
    rescue StandardError
      nil
    end

    def parse_diff(text)
      changed = Hash.new { |h, k| h[k] = [] }
      current_file = nil
      current_new_line = nil

      text.each_line do |raw_line|
        line = raw_line.chomp

        if file_header_line?(line)
          current_file = parse_new_file_path(line)
          next
        end

        if (m = hunk_header_match(line))
          current_new_line = m[1].to_i
          next
        end

        next unless current_file && current_new_line

        current_new_line = process_content_line(line, changed, current_file, current_new_line)
      end

      changed.transform_values { |arr| arr.uniq.sort }
    end

    def file_header_line?(line)
      line.start_with?("+++ ")
    end

    def hunk_header_match(line)
      HUNK_HEADER.match(line)
    end

    def process_content_line(line, changed, current_file, current_new_line)
      case line[0]
      when "+"
        handle_added_line(line, changed, current_file, current_new_line)
      when "-"
        current_new_line
      when " "
        current_new_line + 1
      end
    end

    def handle_added_line(line, changed, current_file, current_new_line)
      return current_new_line if line.start_with?("+++ ")

      changed[current_file] << current_new_line
      current_new_line + 1
    end

    def parse_new_file_path(line)
      return nil if line.end_with?(File::NULL)

      if (m = line.match(%r{\A\+\+\+\sb/(.+)\z}))
        m[1]
      end
    end
  end
end
