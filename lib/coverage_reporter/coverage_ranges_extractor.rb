# frozen_string_literal: true

require "ripper"

module CoverageReporter
  # rubocop:disable Metrics/ClassLength
  class CoverageRangesExtractor
    def initialize(coverage_report, source_dir: nil)
      @coverage_report = coverage_report
      @source_dir = source_dir
    end

    def call
      coverage_map = {}

      return coverage_map unless coverage

      coverage.each do |filename, data|
        # Remove leading slash from file paths for consistency
        normalized_filename = filename.delete_prefix("/")
        source_path = find_source_path(normalized_filename)
        ranges = extract_coverage_ranges(data["lines"], source_path)
        coverage_map[normalized_filename] = ranges
      end

      coverage_map
    end

    private

    def coverage
      return nil unless @coverage_report.is_a?(Hash)

      @coverage_report["coverage"]
    end

    def find_source_path(normalized_filename)
      return nil unless @source_dir

      source_path = File.join(@source_dir, normalized_filename)
      File.exist?(source_path) ? source_path : nil
    end

    def extract_coverage_ranges(lines, source_path=nil)
      return { actual_ranges: [], display_ranges: [], relevant_ranges: [] } unless lines.is_a?(Array)

      result = process_coverage_lines(lines)
      result[:display_uncovered_lines] = apply_method_grouping(result, lines, source_path) if source_path && File.exist?(source_path)

      {
        actual_ranges:   convert_to_ranges(result[:actual_uncovered_lines]),
        display_ranges:  convert_to_ranges(result[:display_uncovered_lines]),
        relevant_ranges: convert_to_ranges(result[:relevant_lines])
      }
    end

    def process_coverage_lines(lines)
      result = initialize_line_arrays
      index = 0

      # rubocop:disable Style/WhileUntilModifier
      while index < lines.length
        index = process_line(lines, result, index)
      end
      # rubocop:enable Style/WhileUntilModifier

      {
        actual_uncovered_lines:  result[:actual_uncovered_lines],
        display_uncovered_lines: result[:display_uncovered_lines],
        relevant_lines:          result[:relevant_lines]
      }
    end

    def initialize_line_arrays
      {
        actual_uncovered_lines:  [],
        display_uncovered_lines: [],
        relevant_lines:          []
      }
    end

    def process_line(lines, result, index)
      coverage_value = lines[index]
      line_number = index + 1

      if coverage_value == 0
        process_uncovered_range(
          lines,
          result[:actual_uncovered_lines],
          result[:display_uncovered_lines],
          result[:relevant_lines],
          index
        )
      else
        result[:relevant_lines] << line_number unless coverage_value.nil?
        index + 1
      end
    end

    def apply_method_grouping(result, lines, source_path)
      method_boundaries = parse_method_boundaries(source_path)
      group_by_methods(
        result[:actual_uncovered_lines],
        result[:display_uncovered_lines],
        lines,
        method_boundaries
      )
    end

    def process_uncovered_range(lines, actual_lines, display_lines, relevant_lines, start_index)
      index = start_index
      add_uncovered_line(actual_lines, display_lines, relevant_lines, index + 1)
      index += 1

      # Continue through consecutive 0s and nils
      while index < lines.length
        coverage_value = lines[index]
        line_number = index + 1

        if coverage_value == 0
          add_uncovered_line(actual_lines, display_lines, relevant_lines, line_number)
          index += 1
        elsif coverage_value.nil? && should_continue_range?(lines, index)
          display_lines << line_number
          index += 1
        else
          break
        end
      end

      index
    end

    def add_uncovered_line(actual_lines, display_lines, relevant_lines, line_number)
      actual_lines << line_number
      display_lines << line_number
      relevant_lines << line_number
    end

    def should_continue_range?(lines, index)
      return false unless lines[index].nil?

      # Include nil only if it's immediately followed by an uncovered line (0)
      index + 1 < lines.length && lines[index + 1] == 0
    end

    def convert_to_ranges(lines)
      return [] if lines.empty?

      ranges = []
      start_line = lines.first
      end_line = lines.first

      lines.each_cons(2) do |current, next_line|
        if next_line == current + 1
          # Consecutive lines, extend the range
          end_line = next_line
        else
          # Gap found, close current range and start new one
          ranges << [start_line, end_line]
          start_line = next_line
          end_line = next_line
        end
      end

      # Add the last range
      ranges << [start_line, end_line]
      ranges
    end

    def parse_method_boundaries(source_path)
      source_code = File.read(source_path)
      boundaries = []

      # Use Ripper.sexp to understand structure and Ripper.lex for line numbers
      sexp = Ripper.sexp(source_code)
      return boundaries unless sexp

      # Extract method boundaries by traversing the AST
      extract_method_boundaries(sexp, source_code, boundaries)
      boundaries.sort_by { |b| b[:start_line] }
    end

    def extract_method_boundaries(sexp, source_code, boundaries)
      return unless sexp.is_a?(Array)

      type = sexp[0]
      case type
      when :def
        # :def [name, params, body]
        extract_def_method(sexp, source_code, boundaries)
      when :defs
        # :defs [receiver, :".", name, params, body]
        extract_defs_method(sexp, source_code, boundaries)
      end

      # Recursively process all children
      sexp.each do |item|
        extract_method_boundaries(item, source_code, boundaries) if item.is_a?(Array)
      end
    end

    def extract_def_method(sexp, source_code, boundaries)
      extract_method_from_node(sexp[1], source_code, boundaries)
    end

    def extract_defs_method(sexp, source_code, boundaries)
      # defs structure: [:defs, receiver, :".", name, params, body]
      extract_method_from_node(sexp[3], source_code, boundaries)
    end

    def extract_method_from_node(method_name_node, source_code, boundaries)
      return unless method_name_node.is_a?(Array) && method_name_node.length >= 3

      location = method_name_node[2]
      return unless location.is_a?(Array) && location.length >= 1

      def_line = location[0]
      return unless def_line.is_a?(Integer)

      end_line = find_matching_end(source_code, def_line)
      return unless end_line

      boundaries << { start_line: def_line, end_line: end_line }
    end

    def find_matching_end(source_code, def_line)
      lines = source_code.lines
      return nil if def_line > lines.length

      # Use a stack-based approach to find matching end
      depth = 0
      start_idx = def_line - 1

      (start_idx...lines.length).each do |idx|
        line = lines[idx]
        # Count def/end keywords (simplified - doesn't handle strings/comments perfectly)
        # But should work for most cases
        depth += line.scan(/\bdef\b/).length
        depth -= line.scan(/\bend\b/).length

        return idx + 1 if depth == 0 && idx > start_idx
      end

      lines.length # Fallback to end of file
    end

    def group_by_methods(actual_uncovered_lines, display_uncovered_lines, coverage_lines, method_boundaries)
      return display_uncovered_lines if method_boundaries.empty? || actual_uncovered_lines.empty?

      line_to_method = build_line_to_method_map(method_boundaries)
      method_uncovered_lines, uncovered_lines_not_in_method = group_uncovered_by_method(
        actual_uncovered_lines,
        line_to_method
      )

      grouped_lines = uncovered_lines_not_in_method.dup
      grouped_lines = process_methods_for_grouping(
        method_uncovered_lines,
        display_uncovered_lines,
        coverage_lines,
        grouped_lines
      )
      add_display_lines_not_in_methods(display_uncovered_lines, line_to_method, grouped_lines)

      grouped_lines.sort.uniq
    end

    def build_line_to_method_map(method_boundaries)
      line_to_method = {}
      method_boundaries.each do |boundary|
        (boundary[:start_line]..boundary[:end_line]).each do |line_num|
          line_to_method[line_num] = boundary
        end
      end
      line_to_method
    end

    def group_uncovered_by_method(actual_uncovered_lines, line_to_method)
      method_uncovered_lines = Hash.new { |h, k| h[k] = [] }
      uncovered_lines_not_in_method = []

      actual_uncovered_lines.each do |line_num|
        if line_to_method[line_num]
          method_uncovered_lines[line_to_method[line_num]] << line_num
        else
          uncovered_lines_not_in_method << line_num
        end
      end

      [method_uncovered_lines, uncovered_lines_not_in_method]
    end

    def process_methods_for_grouping(method_uncovered_lines, display_uncovered_lines, coverage_lines, grouped_lines)
      method_uncovered_lines.each_key do |method|
        if method_fully_uncovered?(method, coverage_lines)
          add_full_method_range(method, grouped_lines)
        else
          add_partial_method_lines(method, display_uncovered_lines, grouped_lines)
        end
      end
      grouped_lines
    end

    def method_fully_uncovered?(method, coverage_lines)
      method_executable_lines = find_executable_lines_in_method(
        method[:start_line],
        method[:end_line],
        coverage_lines
      )
      method_executable_lines.any? && method_executable_lines.all? { |line_idx| coverage_lines[line_idx] == 0 }
    end

    def add_full_method_range(method, grouped_lines)
      (method[:start_line]..method[:end_line]).each do |line_num|
        grouped_lines << line_num unless grouped_lines.include?(line_num)
      end
    end

    def add_partial_method_lines(method, display_uncovered_lines, grouped_lines)
      display_uncovered_lines.each do |line_num|
        next unless line_num.between?(method[:start_line], method[:end_line]) && !grouped_lines.include?(line_num)

        grouped_lines << line_num
      end
    end

    def add_display_lines_not_in_methods(display_uncovered_lines, line_to_method, grouped_lines)
      display_uncovered_lines.each do |line_num|
        grouped_lines << line_num unless line_to_method[line_num]
      end
    end

    def find_executable_lines_in_method(start_line, end_line, coverage_lines)
      executable_lines = []
      ((start_line - 1)...end_line).each do |line_idx|
        next if line_idx >= coverage_lines.length

        # A line is considered executable if it has coverage data (not nil)
        # nil typically means the line is not executable (comment, blank, etc.)
        executable_lines << line_idx unless coverage_lines[line_idx].nil?
      end
      executable_lines
    end
    # rubocop:enable Metrics/ClassLength
  end
end
