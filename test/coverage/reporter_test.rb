# frozen_string_literal: true

require "test_helper"

module Coverage
  class ReporterTest < Minitest::Test
    def test_that_it_has_a_version_number
      refute_nil ::Coverage::Reporter::VERSION
    end
  end
end
