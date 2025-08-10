# frozen_string_literal: true

require "spec_helper"

RSpec.describe "CoverageReporter::VERSION" do
  it "is defined" do
    expect(defined?(CoverageReporter::VERSION)).to eq("constant")
  end

  it "matches semantic versioning (x.y.z)" do
    expect(CoverageReporter::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
