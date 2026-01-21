# Coverage Reporter

[![Gem Version](https://img.shields.io/gem/v/coverage-reporter)](https://rubygems.org/gems/coverage-reporter)
[![Gem Downloads](https://img.shields.io/gem/dt/coverage-reporter)](https://www.ruby-toolbox.com/projects/coverage-reporter)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/gabrieltaylor/coverage-reporter/ci.yml)](https://github.com/gabrieltaylor/coverage-reporter/actions/workflows/ci.yml)

Report code coverage from SimpleCov coverage reports to a GitHub pull request. This tool analyzes your test coverage data and posts detailed comments on pull requests, highlighting uncovered lines in modified code.

---

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [CI/CD Integration](#cicd-integration)
- [Command Line Options](#command-line-options)
- [Environment Variables](#environment-variables)
- [How It Works](#how-it-works)
- [License](#license)
- [Code of Conduct](#code-of-conduct)
- [Contributing](#contributing)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'coverage-reporter'
```

And then execute:

```bash
bundle install
```

Or install it directly:

```bash
gem install coverage-reporter
```

## Quick Start

1. **Generate a SimpleCov coverage report** in your test suite:
   ```ruby
   # In your test helper or spec_helper
   require 'simplecov'
   SimpleCov.start
   ```

2. **Set up environment variables**:
   ```bash
   export GITHUB_TOKEN="your_github_token_here"
   export REPO="owner/repository"
   export PR_NUMBER="123"
   export COMMIT_SHA="abc123def456"
   ```

3. **Run the coverage reporter**:
   ```bash
   coverage-reporter report
   ```

   Or use the `collate` command to merge multiple coverage files from parallel test runs:
   ```bash
   coverage-reporter collate
   ```

The `report` command will automatically:
- Load your coverage data from `coverage/coverage.json`
- Fetch the pull request diff from GitHub
- Identify uncovered lines in modified code
- Post inline comments on uncovered lines
- Add a global coverage summary comment

## Configuration

### Required Settings

- **GitHub Token**: A personal access token with `repo` permissions
- **Repository**: GitHub repository in `owner/repo` format
- **Pull Request Number**: The PR number to comment on
- **Commit SHA**: The commit SHA being analyzed

### Optional Settings

- **Coverage Report Path**: Path to your SimpleCov coverage.json file (default: `coverage/coverage.json`)
- **Report URL**: CI build URL for linking back to your build (default: `$REPORT_URL`)
- **Source Directory**: Source directory for coverage files (default: `$SOURCE_DIR`)

## Usage Examples

### Basic Usage

```bash
coverage-reporter report \
  --github-token "$GITHUB_TOKEN" \
  --repo "myorg/myrepo" \
  --pr-number "42" \
  --commit-sha "$GITHUB_SHA"
```

### Custom Coverage Report Path

```bash
coverage-reporter report \
  --github-token "$GITHUB_TOKEN" \
  --repo "myorg/myrepo" \
  --pr-number "42" \
  --commit-sha "$GITHUB_SHA" \
  --coverage-report-path "test/coverage/coverage.json"
```

### With Report URL

```bash
coverage-reporter report \
  --github-token "$GITHUB_TOKEN" \
  --repo "myorg/myrepo" \
  --pr-number "42" \
  --commit-sha "$GITHUB_SHA" \
  --report-url "https://github.com/myorg/myrepo/actions/runs/123456"
```

### Collate Multiple Coverage Files

The `collate` command merges multiple coverage files (useful for parallel test runs):

```bash
coverage-reporter collate \
  --coverage-dir "coverage" \
  --github-token "$GITHUB_TOKEN" \
  --repo "myorg/myrepo" \
  --pr-number "42"
```

With `--modified-only` to filter to only modified files:

```bash
coverage-reporter collate \
  --coverage-dir "coverage" \
  --modified-only \
  --github-token "$GITHUB_TOKEN" \
  --repo "myorg/myrepo" \
  --pr-number "42"
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Test Coverage
on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.1
          bundler-cache: true

      - name: Run tests with coverage
        run: bundle exec rspec
        env:
          COVERAGE: true

      - name: Report coverage
        run: bundle exec coverage-reporter report
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
          PR_NUMBER: ${{ github.event.number }}
          COMMIT_SHA: ${{ github.sha }}
          REPORT_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

## Command Line Options

### `report` Command

| Option | Description | Default | Environment Variable |
|--------|-------------|---------|---------------------|
| `--github-token TOKEN` | GitHub personal access token | `$GITHUB_TOKEN` | `GITHUB_TOKEN` |
| `--repo REPO` | GitHub repository (owner/repo) | `$REPO` | `REPO` |
| `--pr-number NUMBER` | Pull request number | `$PR_NUMBER` | `PR_NUMBER` |
| `--commit-sha SHA` | Git commit SHA | `$COMMIT_SHA` | `COMMIT_SHA` |
| `--coverage-report-path PATH` | Path to coverage.json | `coverage/coverage.json` | `COVERAGE_REPORT_PATH` |
| `--report-url URL` | CI build URL for links | `$REPORT_URL` | `REPORT_URL` |
| `--source-dir DIR` | Source directory for coverage files | `$SOURCE_DIR` | `SOURCE_DIR` |
| `--help` | Show help message | - | - |

### `collate` Command

| Option | Description | Default | Environment Variable |
|--------|-------------|---------|---------------------|
| `--coverage-dir DIR` | Directory containing coverage files | `coverage` | - |
| `--modified-only` | Filter to only modified files | `false` | - |
| `--github-token TOKEN` | GitHub token (required for `--modified-only`) | `$GITHUB_TOKEN` | `GITHUB_TOKEN` |
| `--repo REPO` | Repository (required for `--modified-only`) | `$REPO` | `REPO` |
| `--pr-number PR_NUMBER` | Pull request number (required for `--modified-only`) | `$PR_NUMBER` | `PR_NUMBER` |
| `--working-dir DIR` | Working directory for coverage files | - | - |
| `--help` | Show help message | - | - |

## Environment Variables

All command-line options can be set via environment variables:

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export REPO="myorg/myrepo"
export PR_NUMBER="123"
export COMMIT_SHA="abc123def456"
export COVERAGE_REPORT_PATH="coverage/coverage.json"
export REPORT_URL="https://ci.example.com/build/123"
export SOURCE_DIR="/path/to/source"
```

## How It Works

### `report` Command

1. **Loads Coverage Data**: Reads SimpleCov's `coverage.json` file to understand which lines are covered by tests
2. **Fetches PR Diff**: Retrieves the pull request diff from GitHub to identify modified lines
3. **Finds Intersections**: Identifies uncovered lines that were modified in the PR
4. **Posts Inline Comments**: Adds comments directly on uncovered lines in the diff
5. **Creates Summary**: Posts a global comment with overall coverage statistics

### `collate` Command

The `collate` command merges multiple coverage files from parallel test runs:

1. **Finds Coverage Files**: Scans the coverage directory for `resultset-*.json` files
2. **Optionally Filters**: If `--modified-only` is used, filters to only files modified in the PR
3. **Merges Coverage**: Uses SimpleCov's collate feature to merge all coverage data
4. **Generates Reports**: Creates both JSON and HTML coverage reports

### GitHub Token Permissions

Your GitHub token needs the following permissions:
- `repo` (Full control of private repositories)
- `public_repo` (Access public repositories)

Create a token at: https://github.com/settings/tokens

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Contributing

Pull requests are welcome! Please read our [contribution guidelines](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
