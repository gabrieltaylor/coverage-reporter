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

  describe "#valid_log_level" do
    it "returns 'INFO' when env_level is nil" do
      expect(described_class.send(:valid_log_level, nil)).to eq("INFO")
    end

    it "returns 'INFO' when env_level is empty string" do
      expect(described_class.send(:valid_log_level, "")).to eq("INFO")
    end

    it "returns 'INFO' when env_level is whitespace only" do
      expect(described_class.send(:valid_log_level, "   ")).to eq("INFO")
    end

    it "returns 'DEBUG' when env_level is 'debug'" do
      expect(described_class.send(:valid_log_level, "debug")).to eq("DEBUG")
    end

    it "returns 'DEBUG' when env_level is 'DEBUG'" do
      expect(described_class.send(:valid_log_level, "DEBUG")).to eq("DEBUG")
    end

    it "returns 'INFO' when env_level is 'info'" do
      expect(described_class.send(:valid_log_level, "info")).to eq("INFO")
    end

    it "returns 'INFO' when env_level is 'INFO'" do
      expect(described_class.send(:valid_log_level, "INFO")).to eq("INFO")
    end

    it "returns 'WARN' when env_level is 'warn'" do
      expect(described_class.send(:valid_log_level, "warn")).to eq("WARN")
    end

    it "returns 'WARN' when env_level is 'WARN'" do
      expect(described_class.send(:valid_log_level, "WARN")).to eq("WARN")
    end

    it "returns 'ERROR' when env_level is 'error'" do
      expect(described_class.send(:valid_log_level, "error")).to eq("ERROR")
    end

    it "returns 'ERROR' when env_level is 'ERROR'" do
      expect(described_class.send(:valid_log_level, "ERROR")).to eq("ERROR")
    end

    it "returns 'INFO' when env_level is invalid" do
      expect(described_class.send(:valid_log_level, "INVALID")).to eq("INFO")
    end

    it "returns 'INFO' when env_level is 'TRACE'" do
      expect(described_class.send(:valid_log_level, "TRACE")).to eq("INFO")
    end

    it "returns 'INFO' when env_level is 'FATAL'" do
      expect(described_class.send(:valid_log_level, "FATAL")).to eq("INFO")
    end

    it "handles mixed case input correctly" do
      expect(described_class.send(:valid_log_level, "DeBuG")).to eq("DEBUG")
      expect(described_class.send(:valid_log_level, "InFo")).to eq("INFO")
      expect(described_class.send(:valid_log_level, "WaRn")).to eq("WARN")
      expect(described_class.send(:valid_log_level, "ErRoR")).to eq("ERROR")
    end
  end
end
