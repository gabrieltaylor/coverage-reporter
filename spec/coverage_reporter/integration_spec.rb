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
      report_url:           "https://ci.example.com/build/123"
    }
  end

  context "when processing a real PR" do
    it "generates expected comment requests based on coverage data and PR diff", :vcr do
      VCR.use_cassette("real_pr_5") do
        # Capture any requests that would be made to create comments
        comment_requests = []

        # Create a real Octokit client that VCR can intercept
        octokit_client = Octokit::Client.new(access_token: "fake_token_for_testing")
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)

        # Mock the POST request for inline comments
        allow(octokit_client).to receive(:post) do |path, payload|
          if path.include?("/pulls/") && path.include?("/comments")
            comment_requests << {
              type:    "inline_comment",
              path:    path,
              payload: payload
            }
          end
        end

        # Mock the add_comment method for global comments
        allow(octokit_client).to receive(:add_comment) do |repo, pr_number, body|
          comment_requests << {
            type:      "global_comment",
            repo:      repo,
            pr_number: pr_number,
            body:      body
          }
        end

        # Mock the update_comment method for updating global comments
        allow(octokit_client).to receive(:update_comment) do |repo, id, body|
          comment_requests << {
            type: "update_global_comment",
            repo: repo,
            id:   id,
            body: body
          }
        end

        # Mock the update_pull_request_comment method for updating inline comments
        allow(octokit_client).to receive(:update_pull_request_comment) do |repo, id, body|
          comment_requests << {
            type: "update_inline_comment",
            repo: repo,
            id:   id,
            body: body
          }
        end

        # Mock other required methods to return empty arrays (no existing comments)
        allow(octokit_client).to receive_messages(
          pull_request_comments: [],
          issue_comments:        []
        )

        # Let VCR handle the pull_request method for diff retrieval

        # Run the coverage reporter - VCR will automatically provide the diff from the cassette
        runner = CoverageReporter::ReportRunner.new(options)
        runner.run

        # Assert on the comment requests that were generated
        expected_requests = JSON.parse(File.read("spec/fixtures/comment_requests.json"))
        expect(JSON.pretty_generate(comment_requests)).to eql(JSON.pretty_generate(expected_requests))

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

    it "updates existing comments when they already exist on the PR", :vcr do
      VCR.use_cassette("real_pr_5") do
        # Capture any requests that would be made to create/update comments
        comment_requests = []

        # Mock existing inline comments - we'll create a more generic matcher
        existing_inline_comments = []

        # Mock existing global comment
        existing_global_comments = [
          instance_double(
            Comment,
            id:   54_321,
            body: "<!-- coverage-comment-marker -->\n🧪 **Test Coverage Summary**\n\n" \
                  "✅ **N/A%** of changed lines are covered.\n\n_Commit: abc123def456_\n"
          )
        ]

        # Create a real Octokit client that VCR can intercept
        octokit_client = Octokit::Client.new(access_token: "fake_token_for_testing")
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)

        # Mock the POST request for new inline comments (shouldn't be called)
        allow(octokit_client).to receive(:post) do |path, payload|
          if path.include?("/pulls/") && path.include?("/comments")
            comment_requests << {
              type:    "new_inline_comment",
              path:    path,
              payload: payload
            }
          end
        end

        # Mock the add_comment method for new global comments (shouldn't be called)
        allow(octokit_client).to receive(:add_comment) do |repo, pr_number, body|
          comment_requests << {
            type:      "new_global_comment",
            repo:      repo,
            pr_number: pr_number,
            body:      body
          }
        end

        # Mock the update_comment method for updating global comments
        allow(octokit_client).to receive(:update_comment) do |repo, id, body|
          comment_requests << {
            type: "update_global_comment",
            repo: repo,
            id:   id,
            body: body
          }
        end

        # Mock the update_pull_request_comment method for updating inline comments
        allow(octokit_client).to receive(:update_pull_request_comment) do |repo, id, body|
          comment_requests << {
            type: "update_inline_comment",
            repo: repo,
            id:   id,
            body: body
          }
        end

        # Mock methods to return existing comments
        allow(octokit_client).to receive_messages(
          pull_request_comments: existing_inline_comments,
          issue_comments:        existing_global_comments
        )

        # Let VCR handle the pull_request method for diff retrieval

        # Run the coverage reporter - VCR will automatically provide the diff from the cassette
        runner = CoverageReporter::ReportRunner.new(options)
        runner.run

        # Assert on the comment requests that were generated
        expect(comment_requests).not_to be_empty

        # Verify we have update requests
        request_types = comment_requests.map { |req| req[:type] }.uniq
        expect(request_types).to include("update_global_comment")

        # Verify global comment update
        global_updates = comment_requests.select { |req| req[:type] == "update_global_comment" }
        expect(global_updates.length).to eq(1)
        global_update = global_updates.first
        expect(global_update[:repo]).to eq("gabrieltaylor/coverage-reporter")
        expect(global_update[:id]).to eq(54_321)
        expect(global_update[:body]).to include("<!-- coverage-comment-marker -->")
        expect(global_update[:body]).to include("Test Coverage Summary")

        # Verify inline comment updates (if any)
        inline_updates = comment_requests.select { |req| req[:type] == "update_inline_comment" }
        if inline_updates.any?
          inline_updates.each do |update|
            expect(update[:id]).to eq(12_345)
            expect(update[:body]).to include("<!-- coverage-inline-marker -->")
            expect(update[:body]).to include("not covered by tests")
          end
        end

        # Verify we have some inline comment activity (either new or updates)
        inline_activity = comment_requests.select { |req| req[:type].include?("inline_comment") }
        expect(inline_activity).not_to be_empty
      end
    end
  end
end
