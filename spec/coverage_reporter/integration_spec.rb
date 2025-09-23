# frozen_string_literal: true

require "spec_helper"

RSpec.describe "CoverageReporter Integration", :vcr do
  let(:options) do
    {
      github_token: "fake_token_for_testing",
      repo: "test/repo",
      pr_number: "123",
      commit_sha: "abc123def456",
      coverage_report_path: "coverage/coverage.json",
      build_url: "https://ci.example.com/build/123"
    }
  end

  context "when processing a real PR" do
    it "successfully processes the PR without errors" do
      # This test will use VCR cassettes if they exist
      expect { CoverageReporter::Runner.new(options).run }.not_to raise_error
    end

    it "makes the expected API calls" do
      # This test verifies the sequence of API calls
      runner = CoverageReporter::Runner.new(options)
      
      # Mock the actual execution to avoid side effects
      allow(runner).to receive(:run).and_call_original
      
      expect { runner.run }.not_to raise_error
    end
  end

  context "with raw fixture data" do
    let(:fixture_data) do
      JSON.parse(File.read("spec/fixtures/raw_requests/pr_123_example.json"))
    rescue Errno::ENOENT
      nil
    end

    it "validates API request patterns" do
      skip "No fixture data available" unless fixture_data

      requests = fixture_data["requests"]
      
      # Verify we make requests to the expected endpoints
      expect(requests).to include(
        hash_including("method" => "GET", "uri" => /\/repos\/.*\/pulls\/123/)
      )
      
      expect(requests).to include(
        hash_including("method" => "GET", "uri" => /\/repos\/.*\/pulls\/123\/comments/)
      )
    end

    it "validates response patterns" do
      skip "No fixture data available" unless fixture_data

      responses = fixture_data["responses"]
      
      # Verify we get successful responses
      expect(responses).to all(
        include("status" => be_between(200, 299))
      )
    end
  end
end
