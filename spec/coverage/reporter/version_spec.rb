# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Coverage::Reporter::VERSION" do
  it "is defined" do
    expect(defined?(Coverage::Reporter::VERSION)).to eq("constant")
  end

  it "matches semantic versioning (x.y.z)" do
    expect(Coverage::Reporter::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
