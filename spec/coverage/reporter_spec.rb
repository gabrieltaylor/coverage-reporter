# frozen_string_literal: true

require "spec_helper"

RSpec.describe Coverage::Reporter do
  it "defines the Coverage module" do
    expect(defined?(Coverage)).to eq("constant")
    expect(Coverage).to be_a(Module)
  end

  it "defines the Reporter submodule" do
    expect(defined?(Coverage::Reporter)).to eq("constant")
    expect(Coverage::Reporter).to be_a(Module)
  end

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
