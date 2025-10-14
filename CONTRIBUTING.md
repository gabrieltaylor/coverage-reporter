# Contributing to Coverage Reporter

Thank you for your interest in contributing to Coverage Reporter! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)
- [Reporting Issues](#reporting-issues)
- [Getting Help](#getting-help)

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to gabriel.taylor.russ@gmail.com.

## Getting Started

### Prerequisites

- Ruby 3.1 or higher
- Bundler
- Git

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/coverage-reporter.git
   cd coverage-reporter
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/gabrieltaylor/coverage-reporter.git
   ```

## Development Setup

1. **Install dependencies**:
   ```bash
   bundle install
   ```

2. **Verify your setup**:
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

3. **Install the gem locally** (optional):
   ```bash
   bundle exec rake install
   ```

## Making Changes

### Branch Strategy

- Create a feature branch from `main`:
  ```bash
  git checkout main
  git pull upstream main
  git checkout -b feature/your-feature-name
  ```

- Use descriptive branch names:
  - `feature/add-new-option`
  - `fix/handle-edge-case`
  - `docs/update-readme`

### Commit Messages

Follow these guidelines for commit messages:

- Use the imperative mood ("Add feature" not "Added feature")
- Keep the first line under 50 characters
- Use the body to explain what and why, not how
- Reference issues when applicable: `Fixes #123`

Examples:
```
Add support for custom coverage report paths

This allows users to specify alternative locations for their
coverage.json files, improving flexibility for different
project structures.

Fixes #45
```

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/coverage_reporter/runner_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Test Structure

- Unit tests: `spec/coverage_reporter/*_spec.rb`
- Integration tests: `spec/coverage_reporter/integration_spec.rb`
- Fixtures: `spec/fixtures/`

### Writing Tests

- Write tests for new functionality
- Ensure existing tests continue to pass
- Use descriptive test names
- Follow the AAA pattern (Arrange, Act, Assert)
- Mock external dependencies (GitHub API calls)

Example:
```ruby
describe "#new_feature" do
  it "handles the expected case" do
    # Arrange
    input = "test input"

    # Act
    result = subject.new_feature(input)

    # Assert
    expect(result).to eq("expected output")
  end
end
```

### VCR Cassettes

For integration tests that make HTTP requests:

- Use VCR to record real API interactions
- Store cassettes in `spec/fixtures/vcr_cassettes/`
- Update cassettes when API behavior changes
- Never commit sensitive data in cassettes

## Code Style

### RuboCop

This project uses RuboCop for code style enforcement:

```bash
# Check style issues
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Check specific file
bundle exec rubocop lib/coverage_reporter/runner.rb
```

### Style Guidelines

- Follow Ruby style conventions
- Use `frozen_string_literal: true` at the top of files
- Prefer single quotes for strings unless interpolation is needed
- Use meaningful variable and method names
- Keep methods small and focused
- Add comments for complex logic

### Documentation

- Document public methods with YARD-style comments
- Update README.md for user-facing changes
- Add examples for new features

## Submitting Changes

### Pull Request Process

1. **Ensure tests pass**:
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

2. **Update documentation** if needed

3. **Push your changes**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create a Pull Request**:
   - Use a clear, descriptive title
   - Reference any related issues
   - Provide a detailed description of changes
   - Include screenshots for UI changes

### Pull Request Template

```markdown
## Description
Brief description of the changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Integration tests updated if needed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

### Review Process

- All PRs require review before merging
- Address feedback promptly
- Keep PRs focused and reasonably sized
- Squash commits when requested

## Release Process

Releases are handled by the maintainer:

1. Update version in `lib/coverage_reporter/version.rb`
2. Update `CHANGELOG.md`
3. Create a release tag
4. Push to trigger GitHub Actions release workflow

### Version Bumping

Use semantic versioning:
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

- Ruby version
- Gem version
- Steps to reproduce
- Expected vs actual behavior
- Error messages/logs
- Sample coverage.json (if relevant)

### Feature Requests

For feature requests:

- Describe the use case
- Explain why it would be valuable
- Consider implementation complexity
- Check for existing issues first

## Getting Help

- **Issues**: Use GitHub Issues for bugs and feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Email**: Contact gabriel.taylor.russ@gmail.com for sensitive matters

## Development Tips

### Local Testing with Real GitHub API

For testing with real GitHub API calls:

1. Create a test repository
2. Set up environment variables:
   ```bash
   export GITHUB_TOKEN="your_test_token"
   export REPO="your-username/test-repo"
   export PR_NUMBER="1"
   export COMMIT_SHA="abc123"
   ```
3. Run the tool locally:
   ```bash
   bundle exec exe/coverage-reporter
   ```

### Debugging

- Use `puts` or `p` for debugging (remove before committing)
- Check VCR cassettes for API interaction issues
- Use `binding.pry` for interactive debugging

### Performance

- Consider performance implications of changes
- Profile if making significant changes
- Keep API calls minimal

## Thank You

Thank you for contributing to Coverage Reporter! Your contributions help make this tool better for everyone in the Ruby community.
