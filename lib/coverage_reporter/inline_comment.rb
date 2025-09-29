# frozen_string_literal: true

module CoverageReporter
  class InlineComment
    attr_reader :path, :start_line, :line, :body

    def initialize(path:, start_line:, line:, body:)
      @path = path
      @start_line = start_line
      @line = line
      @body = body
    end

    def single_line?
      start_line == line
    end

    def range?
      !single_line?
    end
  end
end
