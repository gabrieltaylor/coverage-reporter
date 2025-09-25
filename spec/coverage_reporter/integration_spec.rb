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
        allow_any_instance_of(Octokit::Client).to receive(:update_comment) do |client, repo, id, body|
          comment_requests << {
            type: "update_global_comment",
            repo: repo,
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

    it "updates existing comments when they already exist on the PR", :vcr do
      VCR.use_cassette("real_pr_5") do
        # Capture any requests that would be made to create/update comments
        comment_requests = []
        
        # Mock existing inline comments - we'll create a more generic matcher
        existing_inline_comments = []
        
        # Create a mock that will match any coverage comment
        allow_any_instance_of(CoverageReporter::PullRequest).to receive(:find_existing_inline_comment) do |pr, file_path, start_line, end_line|
          # Return a mock comment for any coverage-related file
          if file_path.include?("coverage_reporter")
            double(
              id: 12345,
              body: "<!-- coverage-inline-marker -->\n❌ Line #{start_line} is not covered by tests.\n\n_File: #{file_path}, line #{start_line}_\n_Commit: abc123def456_",
              path: file_path,
              line: end_line,
              start_line: start_line
            )
          else
            nil
          end
        end
        
        # Mock existing global comment
        existing_global_comments = [
          double(
            id: 54321,
            body: "<!-- coverage-comment-marker -->\n🧪 **Test Coverage Summary**\n\n✅ **N/A%** of changed lines are covered.\n\n_Commit: abc123def456_\n"
          )
        ]
        
        # Mock the POST request for new inline comments (shouldn't be called)
        allow_any_instance_of(Octokit::Client).to receive(:post) do |client, path, payload|
          if path.include?("/pulls/") && path.include?("/comments")
            comment_requests << {
              type: "new_inline_comment",
              path: path,
              payload: payload
            }
          end
        end
        
        # Mock the add_comment method for new global comments (shouldn't be called)
        allow_any_instance_of(Octokit::Client).to receive(:add_comment) do |client, repo, pr_number, body|
          comment_requests << {
            type: "new_global_comment",
            repo: repo,
            pr_number: pr_number,
            body: body
          }
        end
        
        # Mock the update_comment method for updating global comments
        allow_any_instance_of(Octokit::Client).to receive(:update_comment) do |client, repo, id, body|
          comment_requests << {
            type: "update_global_comment",
            repo: repo,
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
        
        # Mock methods to return existing comments
        allow_any_instance_of(Octokit::Client).to receive(:pull_request_comments).and_return(existing_inline_comments)
        allow_any_instance_of(Octokit::Client).to receive(:issue_comments).and_return(existing_global_comments)
        
        # Run the coverage reporter - VCR will automatically provide the diff from the cassette
        runner = CoverageReporter::Runner.new(options)
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
        expect(global_update[:id]).to eq(54321)
        expect(global_update[:body]).to include("<!-- coverage-comment-marker -->")
        expect(global_update[:body]).to include("Test Coverage Summary")
        
        # Verify inline comment updates (if any)
        inline_updates = comment_requests.select { |req| req[:type] == "update_inline_comment" }
        if inline_updates.any?
          inline_updates.each do |update|
            expect(update[:id]).to eq(12345)
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
