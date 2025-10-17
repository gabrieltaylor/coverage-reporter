# Fixture Capture Scripts

This directory contains scripts to help you capture real HTTP requests and responses from running the coverage-reporter against actual GitHub pull requests. These captured interactions can then be used as test fixtures.

## Prerequisites

1. Install the required gems:
   ```bash
   bundle install
   ```

2. Set up your environment variables:
   ```bash
   export GITHUB_TOKEN="your_github_token_here"
   export REPO="owner/repository"
   export PR_NUMBER="123"
   export COMMIT_SHA="abc123def456"
   export COVERAGE_REPORT_PATH="coverage/coverage.json"
   export REPORT_URL="https://ci.example.com/build/123"
   ```

## Available Scripts

### 1. VCR Cassette Capture (`capture_fixtures.rb`)

This script uses VCR to record HTTP interactions in a format that can be replayed in tests.

**Usage:**
```bash
./scripts/capture_fixtures.rb
```

**What it does:**
- Records all HTTP requests/responses using VCR
- Saves them as YAML cassettes in `spec/fixtures/vcr_cassettes/`
- Can be replayed in tests using VCR

**Output:**
- Creates `spec/fixtures/vcr_cassettes/real_pr_123.yml`

### 2. Raw Request Capture (`capture_raw_requests.rb`)

This script captures raw HTTP requests and responses in JSON format for detailed analysis.

**Usage:**
```bash
./scripts/capture_raw_requests.rb
```

**What it does:**
- Intercepts HTTP requests at the Octokit level
- Captures request method, URI, headers, and body
- Captures response status, headers, and body
- Saves everything as pretty-printed JSON

**Output:**
- Creates `spec/fixtures/raw_requests/pr_123_20240101_120000.json`

### 3. Logging Script (`run_with_logging.rb`)

This script runs the normal CLI but with detailed HTTP request/response logging.

**Usage:**
```bash
./scripts/run_with_logging.rb --github-token $GITHUB_TOKEN --repo $REPO --pr-number $PR_NUMBER
```

**What it does:**
- Runs the normal coverage-reporter workflow
- Logs all HTTP requests and responses to stdout
- Useful for debugging and understanding the API calls

## Using Captured Fixtures in Tests

### With VCR Cassettes

```ruby
# In your spec file
RSpec.describe "CoverageReporter Integration" do
  it "processes a real PR", :vcr do
    # VCR will automatically use the cassette
    options = {
      github_token: "fake_token",
      repo: "test/repo",
      pr_number: "123",
      # ... other options
    }

    expect { CoverageReporter::Runner.new(options).run }.not_to raise_error
  end
end
```

### With Raw JSON Fixtures

```ruby
# Load and parse raw request data
def load_fixture(filename)
  JSON.parse(File.read("spec/fixtures/raw_requests/#{filename}"))
end

# Use in tests
it "matches expected API calls" do
  fixture = load_fixture("pr_123_20240101_120000.json")

  expect(fixture["requests"]).to include(
    hash_including("method" => "GET", "uri" => /\/repos\/.*\/pulls\/123/)
  )
end
```

## Best Practices

1. **Use a test repository**: Create a test repository with a PR specifically for capturing fixtures
2. **Clean up after capture**: Delete any comments created during fixture capture
3. **Sanitize sensitive data**: Remove or replace tokens, personal information, etc.
4. **Version control fixtures**: Commit fixture files to git for team sharing
5. **Regular updates**: Re-capture fixtures when GitHub API changes

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub personal access token | `ghp_xxxxxxxxxxxx` |
| `REPO` | Repository in owner/repo format | `octocat/Hello-World` |
| `PR_NUMBER` | Pull request number | `123` |
| `COMMIT_SHA` | Git commit SHA | `abc123def456` |
| `COVERAGE_REPORT_PATH` | Path to coverage.json | `coverage/coverage.json` |
| `REPORT_URL` | CI build URL for links | `https://github.com/owner/repo/actions/runs/123` |

## Troubleshooting

### Common Issues

1. **Authentication errors**: Ensure your GitHub token has the correct permissions
2. **File not found**: Make sure the coverage report file exists
3. **Network errors**: Check your internet connection and GitHub API status
4. **Permission denied**: Ensure the script files are executable (`chmod +x`)

### Debug Mode

Run any script with `DEBUG=1` for more verbose output:
```bash
DEBUG=1 ./scripts/capture_fixtures.rb
```

## Security Notes

- Never commit real GitHub tokens to version control
- Use environment variables or secure credential storage
- Consider using GitHub's test token or a dedicated test account
- Sanitize fixture files before committing if they contain sensitive data
