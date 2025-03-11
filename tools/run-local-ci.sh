#!/bin/bash
# Local CI Testing Script for HDR+ Swift
# This script allows developers to run CI-like tests locally before pushing code.
#
# Usage:
#   ./tools/run-local-ci.sh [OPTIONS]
#
# Options:
#   --platform PLATFORM    Specific platform to test (e.g., macos-14, macos-13)
#   --no-metal             Skip Metal-specific tests
#   --quick                Run a faster subset of tests
#   --help                 Show this help message

set -e

# Default values
SKIP_METAL=false
QUICK_MODE=false
PLATFORM=""
WORKSPACE_ROOT="$(pwd)"
TESTS_DIR="$WORKSPACE_ROOT/test-results"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_help() {
  echo "HDR+ Swift Local CI Testing Script"
  echo ""
  echo "This script runs CI-like tests on your local machine to verify code quality"
  echo "and compatibility before pushing to the remote repository."
  echo ""
  echo "Usage:"
  echo "  ./tools/run-local-ci.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --platform PLATFORM    Specific platform to test (e.g., macos-14, macos-13)"
  echo "  --no-metal             Skip Metal-specific tests"
  echo "  --quick                Run a faster subset of tests"
  echo "  --help                 Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./tools/run-local-ci.sh                   # Run full test suite"
  echo "  ./tools/run-local-ci.sh --quick           # Run basic tests only"
  echo "  ./tools/run-local-ci.sh --no-metal        # Skip Metal-specific tests"
  echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --no-metal)
      SKIP_METAL=true
      shift
      ;;
    --quick)
      QUICK_MODE=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Create test results directory
mkdir -p "$TESTS_DIR"

# Display header
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}     HDR+ Swift Local CI Testing        ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "Running tests with the following settings:"
echo -e "  Platform: ${YELLOW}${PLATFORM:-"Auto-detect"}${NC}"
echo -e "  Quick mode: ${YELLOW}$([ "$QUICK_MODE" = true ] && echo "Enabled" || echo "Disabled")${NC}"
echo -e "  Metal tests: ${YELLOW}$([ "$SKIP_METAL" = true ] && echo "Skipped" || echo "Included")${NC}"
echo ""

# Check environment
echo -e "${BLUE}Checking environment...${NC}"
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" != "Darwin" ]; then
  echo -e "${RED}Error: This script must be run on macOS${NC}"
  exit 1
fi

# Auto-detect platform if not specified
if [ -z "$PLATFORM" ]; then
  OS_VERSION=$(sw_vers -productVersion)
  ARCH=$(uname -m)
  
  # Detect macOS version and set platform
  if [[ "$OS_VERSION" == 14.* ]]; then
    PLATFORM="macos-14"
  elif [[ "$OS_VERSION" == 13.* ]]; then
    PLATFORM="macos-13"
  else
    PLATFORM="macos-legacy"
  fi
  
  echo -e "Auto-detected platform: ${YELLOW}$PLATFORM${NC} (macOS $OS_VERSION, $ARCH)"
else
  echo -e "Using specified platform: ${YELLOW}$PLATFORM${NC}"
fi

# Check for Metal support if not skipped
if [ "$SKIP_METAL" != "true" ]; then
  echo -e "${BLUE}Checking Metal support...${NC}"
  METAL_DIR="$TESTS_DIR/metal-diagnostics"
  mkdir -p "$METAL_DIR"
  
  # Run Metal support check script
  if [ -f "$WORKSPACE_ROOT/.github/scripts/check-metal-support.sh" ]; then
    chmod +x "$WORKSPACE_ROOT/.github/scripts/check-metal-support.sh"
    "$WORKSPACE_ROOT/.github/scripts/check-metal-support.sh" "$METAL_DIR"
    
    # Check if Metal is supported
    METAL_SUPPORTED=$(grep "Metal Supported:" "$METAL_DIR/metal_support_summary.md" | grep -q "true" && echo "true" || echo "false")
    
    if [ "$METAL_SUPPORTED" = "true" ]; then
      echo -e "${GREEN}Metal is supported on this system! 🎉${NC}"
    else
      echo -e "${YELLOW}Warning: Metal is not supported on this system. Metal-specific tests will be skipped.${NC}"
      SKIP_METAL=true
    fi
  else
    echo -e "${YELLOW}Warning: Metal support check script not found. Assuming Metal is available.${NC}"
  fi
fi

# Prepare for test run
echo -e "${BLUE}Preparing for test run...${NC}"

# Check if Xcode is available
if ! xcode-select -p >/dev/null 2>&1; then
  echo -e "${RED}Error: Xcode command line tools not found${NC}"
  echo -e "Please install Xcode command line tools with:"
  echo -e "  xcode-select --install"
  exit 1
fi

# Check for Swift availability
if ! which swift >/dev/null 2>&1; then
  echo -e "${RED}Error: Swift not found${NC}"
  exit 1
fi
SWIFT_VERSION=$(swift --version | head -n 1)
echo -e "Using Swift: ${YELLOW}$SWIFT_VERSION${NC}"

# Run basic lint checks
echo -e "${BLUE}Running lint checks...${NC}"
if [ -x "$(command -v swiftlint)" ]; then
  swiftlint lint --quiet > "$TESTS_DIR/lint-results.txt" || true
  LINT_ISSUES=$(grep -c "warning\\|error" "$TESTS_DIR/lint-results.txt" || echo "0")
  echo -e "SwiftLint found ${YELLOW}$LINT_ISSUES${NC} issue(s)"
else
  echo -e "${YELLOW}SwiftLint not installed, skipping lint checks${NC}"
  echo -e "Consider installing with: brew install swiftlint"
fi

# Test builds
echo -e "${BLUE}Building project...${NC}"
BUILD_LOG="$TESTS_DIR/build-log.txt"

# Determine project type for build command
if [ -f "Package.swift" ]; then
  echo -e "Swift Package project detected"
  
  # Build with SwiftPM
  if [ "$QUICK_MODE" = true ]; then
    echo -e "Building in quick mode (debug configuration)..."
    swift build -c debug > "$BUILD_LOG" 2>&1 || { echo -e "${RED}Build failed!${NC}"; cat "$BUILD_LOG"; exit 1; }
  else
    echo -e "Building in full mode (release configuration)..."
    swift build -c release > "$BUILD_LOG" 2>&1 || { echo -e "${RED}Build failed!${NC}"; cat "$BUILD_LOG"; exit 1; }
  fi
  
  # Run tests
  echo -e "${BLUE}Running tests...${NC}"
  TEST_LOG="$TESTS_DIR/test-log.txt"
  
  if [ "$QUICK_MODE" = true ]; then
    echo -e "Running tests in quick mode..."
    swift test --filter "FunctionalTests" > "$TEST_LOG" 2>&1 || TESTS_FAILED=true
  else
    echo -e "Running full test suite..."
    swift test > "$TEST_LOG" 2>&1 || TESTS_FAILED=true
  fi
  
elif [ -d "*.xcodeproj" ] || [ -d "*.xcworkspace" ]; then
  echo -e "Xcode project detected"
  
  # Find the primary scheme
  SCHEME=$(xcodebuild -list | grep -A 10 "Schemes:" | grep -v "Schemes:" | head -1 | tr -d '[:space:]')
  
  if [ -z "$SCHEME" ]; then
    echo -e "${RED}No scheme found in Xcode project${NC}"
    exit 1
  fi
  
  echo -e "Using scheme: ${YELLOW}$SCHEME${NC}"
  
  # Build with xcodebuild
  if [ "$QUICK_MODE" = true ]; then
    echo -e "Building in quick mode (debug configuration)..."
    xcodebuild build -scheme "$SCHEME" -configuration Debug > "$BUILD_LOG" 2>&1 || { echo -e "${RED}Build failed!${NC}"; cat "$BUILD_LOG"; exit 1; }
  else
    echo -e "Building in full mode (release configuration)..."
    xcodebuild build -scheme "$SCHEME" -configuration Release > "$BUILD_LOG" 2>&1 || { echo -e "${RED}Build failed!${NC}"; cat "$BUILD_LOG"; exit 1; }
  fi
  
  # Run tests
  echo -e "${BLUE}Running tests...${NC}"
  TEST_LOG="$TESTS_DIR/test-log.txt"
  
  if [ "$QUICK_MODE" = true ]; then
    echo -e "Running tests in quick mode..."
    xcodebuild test -scheme "$SCHEME" -configuration Debug -testPlan FunctionalTests > "$TEST_LOG" 2>&1 || TESTS_FAILED=true
  else
    echo -e "Running full test suite..."
    xcodebuild test -scheme "$SCHEME" -configuration Debug > "$TEST_LOG" 2>&1 || TESTS_FAILED=true
  fi
  
else
  echo -e "${RED}Error: No Swift Package or Xcode project found${NC}"
  exit 1
fi

# Run Metal-specific tests if enabled
if [ "$SKIP_METAL" != "true" ]; then
  echo -e "${BLUE}Running Metal-specific tests...${NC}"
  METAL_TEST_LOG="$TESTS_DIR/metal-test-log.txt"
  
  # Set Metal environment variables for better diagnostics
  export MTL_DEBUG_LAYER=1
  export MTL_SHADER_VALIDATION=1
  
  # Run Metal-specific tests if they exist
  if [ -f "Package.swift" ]; then
    swift test --filter "MetalTests" > "$METAL_TEST_LOG" 2>&1 || METAL_TESTS_FAILED=true
  elif [ -d "*.xcodeproj" ] || [ -d "*.xcworkspace" ]; then
    xcodebuild test -scheme "$SCHEME" -configuration Debug -testPlan MetalTests > "$METAL_TEST_LOG" 2>&1 || METAL_TESTS_FAILED=true
  fi
  
  if [ "${METAL_TESTS_FAILED:-false}" = true ]; then
    echo -e "${RED}Metal tests failed!${NC}"
    grep -A 5 "failed" "$METAL_TEST_LOG" || true
  else
    echo -e "${GREEN}Metal tests passed!${NC}"
  fi
fi

# Generate summary
echo -e "${BLUE}Generating summary...${NC}"
SUMMARY_FILE="$TESTS_DIR/summary.md"

cat > "$SUMMARY_FILE" << EOF
# HDR+ Swift Local CI Test Results

Test run on $(date)

## Environment
- Platform: $PLATFORM
- Swift: $SWIFT_VERSION

## Results
EOF

if [ "${TESTS_FAILED:-false}" = true ]; then
  echo "- ❌ Some tests failed" >> "$SUMMARY_FILE"
  
  # Extract failing tests
  FAILED_TESTS=$(grep -A 1 "failed" "$TEST_LOG" || echo "Could not determine failing tests")
  echo "" >> "$SUMMARY_FILE"
  echo "### Failing Tests" >> "$SUMMARY_FILE"
  echo "```" >> "$SUMMARY_FILE"
  echo "$FAILED_TESTS" >> "$SUMMARY_FILE"
  echo "```" >> "$SUMMARY_FILE"
else
  echo "- ✅ All basic tests passed" >> "$SUMMARY_FILE"
fi

if [ "$SKIP_METAL" != "true" ]; then
  if [ "${METAL_TESTS_FAILED:-false}" = true ]; then
    echo "- ❌ Metal tests failed" >> "$SUMMARY_FILE"
    
    # Extract failing Metal tests
    FAILED_METAL_TESTS=$(grep -A 1 "failed" "$METAL_TEST_LOG" || echo "Could not determine failing Metal tests")
    echo "" >> "$SUMMARY_FILE"
    echo "### Failing Metal Tests" >> "$SUMMARY_FILE"
    echo "```" >> "$SUMMARY_FILE"
    echo "$FAILED_METAL_TESTS" >> "$SUMMARY_FILE"
    echo "```" >> "$SUMMARY_FILE"
  else
    echo "- ✅ All Metal tests passed" >> "$SUMMARY_FILE"
  fi
else
  echo "- ⚠️ Metal tests skipped" >> "$SUMMARY_FILE"
fi

# Display summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}          Test Run Complete             ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ "${TESTS_FAILED:-false}" = true ] || [ "${METAL_TESTS_FAILED:-false}" = true ]; then
  echo -e "${RED}Some tests failed. See details in $TESTS_DIR/${NC}"
else
  echo -e "${GREEN}All tests passed! Your code is ready for push.${NC}"
fi

echo -e "Summary file generated: ${YELLOW}$SUMMARY_FILE${NC}"
echo ""

# Exit with appropriate status
if [ "${TESTS_FAILED:-false}" = true ] || [ "${METAL_TESTS_FAILED:-false}" = true ]; then
  exit 1
else
  exit 0
fi 