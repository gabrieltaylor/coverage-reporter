module CoverageReporter
  class CLI
    def self.start(argv)
      options = Options.parse(argv)
      Runner.new(options).run
    end
  end
end
