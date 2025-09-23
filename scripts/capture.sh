#!/bin/bash
# frozen_string_literal: true

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Coverage Reporter Fixture Capture Tool${NC}"
echo ""

# Check if required environment variables are set
check_env_var() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}❌ Error: $1 environment variable is not set${NC}"
        echo "Please set it with: export $1=\"your_value\""
        exit 1
    fi
}

echo -e "${YELLOW}📋 Checking environment variables...${NC}"
check_env_var "GITHUB_TOKEN"
check_env_var "REPO"
check_env_var "PR_NUMBER"

# Optional variables with defaults
COMMIT_SHA=${COMMIT_SHA:-"abc123def456"}
COVERAGE_REPORT_PATH=${COVERAGE_REPORT_PATH:-"coverage/coverage.json"}
BUILD_URL=${BUILD_URL:-"https://ci.example.com/build/123"}

echo -e "${GREEN}✅ All required environment variables are set${NC}"
echo ""

# Display current configuration
echo -e "${BLUE}📊 Current Configuration:${NC}"
echo "  Repository: $REPO"
echo "  PR Number: $PR_NUMBER"
echo "  Commit SHA: $COMMIT_SHA"
echo "  Coverage Report: $COVERAGE_REPORT_PATH"
echo "  Build URL: $BUILD_URL"
echo ""

# Check if coverage report exists
if [ ! -f "$COVERAGE_REPORT_PATH" ]; then
    echo -e "${YELLOW}⚠️  Warning: Coverage report file not found at $COVERAGE_REPORT_PATH${NC}"
    echo "The script will still run, but coverage analysis may fail."
    echo ""
fi

# Menu for script selection
echo -e "${BLUE}🎯 Choose capture method:${NC}"
echo "1) VCR Cassette Capture (recommended for tests)"
echo "2) Raw Request Capture (detailed JSON output)"
echo "3) Logging Mode (verbose console output)"
echo "4) All methods"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "${GREEN}🎬 Starting VCR cassette capture...${NC}"
        ./scripts/capture_fixtures.rb
        ;;
    2)
        echo -e "${GREEN}📊 Starting raw request capture...${NC}"
        ./scripts/capture_raw_requests.rb
        ;;
    3)
        echo -e "${GREEN}📝 Starting logging mode...${NC}"
        ./scripts/run_with_logging.rb \
            --github-token "$GITHUB_TOKEN" \
            --repo "$REPO" \
            --pr-number "$PR_NUMBER" \
            --commit-sha "$COMMIT_SHA" \
            --coverage-report-path "$COVERAGE_REPORT_PATH" \
            --build-url "$BUILD_URL"
        ;;
    4)
        echo -e "${GREEN}🚀 Running all capture methods...${NC}"
        echo ""
        
        echo -e "${YELLOW}1/3: VCR Cassette Capture${NC}"
        ./scripts/capture_fixtures.rb
        echo ""
        
        echo -e "${YELLOW}2/3: Raw Request Capture${NC}"
        ./scripts/capture_raw_requests.rb
        echo ""
        
        echo -e "${YELLOW}3/3: Logging Mode${NC}"
        ./scripts/run_with_logging.rb \
            --github-token "$GITHUB_TOKEN" \
            --repo "$REPO" \
            --pr-number "$PR_NUMBER" \
            --commit-sha "$COMMIT_SHA" \
            --coverage-report-path "$COVERAGE_REPORT_PATH" \
            --build-url "$BUILD_URL"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Capture process completed!${NC}"
echo ""
echo -e "${BLUE}📁 Check these directories for output:${NC}"
echo "  - spec/fixtures/vcr_cassettes/ (VCR cassettes)"
echo "  - spec/fixtures/raw_requests/ (Raw JSON data)"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Review the captured data"
echo "  2. Sanitize any sensitive information"
echo "  3. Use the fixtures in your tests"
echo "  4. Consider cleaning up any test comments on the PR"
