# frozen_string_literal: true

module CoverageReporter
  class InlineComment
    attr_reader :file, :start_line, :end_line, :message, :body

    def initialize(file:, start_line:, end_line:, message:, body:)
      @file = file
      @start_line = start_line
      @end_line = end_line
      @message = message
      @body = body
    end

    def single_line?
      start_line == end_line
    end

    def range?
      !single_line?
    end

    def to_h
      {
        file:       file,
        start_line: start_line,
        end_line:   end_line,
        message:    message,
        body:       body
      }
    end
  end
end
