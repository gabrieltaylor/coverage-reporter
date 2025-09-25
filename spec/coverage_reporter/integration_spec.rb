# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "CoverageReporter Integration" do
  # rubocop:enable RSpec/DescribeClass
  let(:options) do
    {
      github_token:         "fake_token_for_testing",
      repo:                 "gabrieltaylor/coverage-reporter",
      pr_number:            "5",
      commit_sha:           "abc123def456",
      coverage_report_path: "spec/fixtures/coverage.json",
      build_url:            "https://ci.example.com/build/123"
    }
  end

  context "when processing a real PR" do
    it "generates expected comment requests based on coverage data and PR diff", :vcr do
      VCR.use_cassette("real_pr_5") do
        # Capture any requests that would be made to create comments
        comment_requests = []
        
        # Mock the POST request for inline comments
        allow_any_instance_of(Octokit::Client).to receive(:post) do |client, path, payload|
          if path.include?("/pulls/") && path.include?("/comments")
            comment_requests << {
              type: "inline_comment",
              path: path,
              payload: payload
            }
          end
        end
        
        # Mock the add_comment method for global comments
        allow_any_instance_of(Octokit::Client).to receive(:add_comment) do |client, repo, pr_number, body|
          comment_requests << {
            type: "global_comment",
            repo: repo,
            pr_number: pr_number,
            body: body
          }
        end
        
        # Mock the update_comment method for updating global comments
        allow_any_instance_of(Octokit::Client).to receive(:update_comment) do |client, id, body|
          comment_requests << {
            type: "update_global_comment",
            id: id,
            body: body
          }
        end
        
        # Mock the update_pull_request_comment method for updating inline comments
        allow_any_instance_of(Octokit::Client).to receive(:update_pull_request_comment) do |client, repo, id, body|
          comment_requests << {
            type: "update_inline_comment",
            repo: repo,
            id: id,
            body: body
          }
        end
        
        # Mock other required methods to return empty arrays (no existing comments)
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_comments).and_return([])
        allow_any_instance_of(Octokit::Client).to receive(:issue_comments).and_return([])
        
        # Run the coverage reporter - VCR will automatically provide the diff from the cassette
        runner = CoverageReporter::Runner.new(options)
        runner.run

        # Assert on the comment requests that were generated
        expect(JSON.pretty_generate(comment_requests)).to eql(JSON.pretty_generate(JSON.parse(File.read("spec/fixtures/comment_requests.json"))))
        
        # Verify global comment
        global_comments = comment_requests.select { |req| req[:type] == "global_comment" }
        expect(global_comments.length).to eq(1)
        global_comment = global_comments.first
        expect(global_comment[:repo]).to eq("gabrieltaylor/coverage-reporter")
        expect(global_comment[:pr_number]).to eq("5")
        expect(global_comment[:body]).to include("<!-- coverage-comment-marker -->")
        expect(global_comment[:body]).to include("Test Coverage Summary")
        
        # Verify inline comments
        inline_comments = comment_requests.select { |req| req[:type] == "inline_comment" }
        expect(inline_comments.length).to eq(12)
        inline_comments.each do |comment|
          expect(comment[:path]).to include("/pulls/5/comments")
          expect(comment[:payload][:body]).to include("<!-- coverage-inline-marker -->")
          expect(comment[:payload][:body]).to include("not covered by tests")
          expect(comment[:payload][:commit_id]).to eq("abc123def456")
        end
      end
    end
  end
end
