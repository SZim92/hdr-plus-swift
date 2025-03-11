#!/bin/bash
# run-local-ci.sh - Run tests locally similar to CI
#
# This script allows developers to run CI-like tests locally
# to detect potential issues before pushing to the repository
#
# Usage: ./tools/run-local-ci.sh [OPTIONS]
#
# Options:
#   --platform PLATFORM  Specific platform to test (e.g., macos-14, macos-13)
#   --no-metal          Skip Metal-specific tests
#   --quick             Run a faster subset of tests
#   --help              Show this help message

set -e

# Default values
PLATFORM="local"
SKIP_METAL=false
QUICK_MODE=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
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
      echo "Usage: ./tools/run-local-ci.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --platform PLATFORM  Specific platform to test (e.g., macos-14, macos-13)"
      echo "  --no-metal          Skip Metal-specific tests"
      echo "  --quick             Run a faster subset of tests"
      echo "  --help              Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './tools/run-local-ci.sh --help' for usage information"
      exit 1
      ;;
  esac
done

cd "$PROJECT_ROOT"

echo "====================================="
echo "HDR+ Swift Local CI Testing"
echo "====================================="
echo "Platform: $PLATFORM"
echo "Skip Metal: $SKIP_METAL"
echo "Quick Mode: $QUICK_MODE"
echo "====================================="

# Setup the Swift environment
echo "Setting up Swift environment..."
if [ -f ".github/scripts/setup-swift-env.sh" ]; then
  chmod +x .github/scripts/setup-swift-env.sh
  ./.github/scripts/setup-swift-env.sh 'local' 'true' 'true'
else
  echo "Warning: Swift environment setup script not found."
  echo "Continuing with default environment..."
fi

# Check Metal support if not skipping
if [ "$SKIP_METAL" = false ]; then
  echo "Checking for Metal support..."
  METAL_DIR="metal-diagnostics-local"
  mkdir -p "$METAL_DIR"
  
  if [ -f ".github/scripts/check-metal-support.sh" ]; then
    chmod +x .github/scripts/check-metal-support.sh
    ./.github/scripts/check-metal-support.sh "$METAL_DIR"
    
    if [ -f "$METAL_DIR/metal_support_summary.md" ]; then
      METAL_SUPPORTED=$(grep "Metal Supported" "$METAL_DIR/metal_support_summary.md" | grep -q "true" && echo "true" || echo "false")
      if [ "$METAL_SUPPORTED" = "false" ]; then
        echo "Warning: Metal is not supported on this machine."
        echo "Metal-dependent tests may fail."
      else
        echo "Metal support detected."
      fi
    fi
  else
    echo "Warning: Metal support detection script not found."
    echo "Assuming Metal is supported..."
  fi
fi

# Run SwiftLint to check for issues
echo "Running SwiftLint..."
if command -v swiftlint &> /dev/null; then
  if [ -f ".swiftlint.yml" ]; then
    swiftlint lint --config .swiftlint.yml
  else
    swiftlint lint
  fi
else
  echo "Warning: SwiftLint not installed. Skipping linting step."
fi

# Setup Xcode project or Swift package
echo "Setting up project..."
if [ -d "burstphoto.xcodeproj" ]; then
  echo "Found Xcode project..."
  # Check if xcodebuild is available
  if command -v xcodebuild &> /dev/null; then
    echo "Listing available schemes:"
    xcodebuild -project burstphoto.xcodeproj -list
  else
    echo "Error: xcodebuild not found. Cannot build Xcode project."
    exit 1
  fi
elif [ -f "Package.swift" ]; then
  echo "Found Swift package..."
  swift package describe
else
  echo "Error: Neither Xcode project nor Swift package found."
  exit 1
fi

# Run build
echo "Building project..."
if [ -d "burstphoto.xcodeproj" ]; then
  # Build using xcodebuild
  if [ "$QUICK_MODE" = true ]; then
    xcodebuild build -project burstphoto.xcodeproj -scheme gui -destination "platform=macOS" -skipPackagePluginValidation
  else
    xcodebuild build -project burstphoto.xcodeproj -scheme gui -destination "platform=macOS"
  fi
elif [ -f "Package.swift" ]; then
  # Build using Swift PM
  swift build
fi

# Run tests
echo "Running tests..."
if [ -d "burstphoto.xcodeproj" ]; then
  # Test using xcodebuild
  if [ "$QUICK_MODE" = true ]; then
    # Only run a subset of tests in quick mode
    xcodebuild test -project burstphoto.xcodeproj -scheme gui -destination "platform=macOS" -skipPackagePluginValidation -only-testing:UnitTests
  elif [ "$SKIP_METAL" = true ]; then
    # Skip Metal tests
    xcodebuild test -project burstphoto.xcodeproj -scheme gui -destination "platform=macOS" -skip-testing:MetalTests
  else
    # Run all tests
    xcodebuild test -project burstphoto.xcodeproj -scheme gui -destination "platform=macOS"
  fi
elif [ -f "Package.swift" ]; then
  # Test using Swift PM
  swift test
fi

echo "====================================="
echo "Local CI completed"
echo "=====================================" 