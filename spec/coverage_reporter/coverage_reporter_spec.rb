# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter do
  describe "VERSION" do
    it "is defined" do
      expect(defined?(described_class::VERSION)).to eq("constant")
    end

    it "is not nil" do
      expect(described_class::VERSION).not_to be_nil
    end

    it "follows semantic versioning x.y.z" do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
