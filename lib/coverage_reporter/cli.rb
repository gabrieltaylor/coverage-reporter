# frozen_string_literal: true

require "optparse"

module CoverageReporter
  class CLI
    def self.start(argv)
      case argv.first
      when nil
        show_usage_and_exit
      when "report"
        # Report command
        options = Options::Report.parse(argv[1..])
        Runner.new(options).run
      when "collate"
        collate_options = Options::Collate.parse(argv[1..])
        CoverageCollator.new(collate_options).call
      else
        show_unknown_command_error(argv.first)
      end
    end

    private_class_method def self.show_usage_and_exit
      puts "Usage: coverage-reporter <command> [options]"
      print_commands_list
      exit 1
    end

    private_class_method def self.show_unknown_command_error(command)
      puts "Unknown command: #{command}"
      print_commands_list
      exit 1
    end

    private_class_method def self.print_commands_list
      puts ""
      puts "Commands:"
      puts "  report   Generate coverage report and post comments"
      puts "  collate  Collate multiple coverage files"
      puts ""
      puts "Use 'coverage-reporter <command> --help' for command-specific options"
    end
  end
end
