# frozen_string_literal: true

require "optparse"
require_relative "options"
require_relative "runner"

module CoverageReporter
  class CLI
    def self.start(argv)
      options = Options.parse(argv)
      Runner.new(options).run
    end
  end
end
