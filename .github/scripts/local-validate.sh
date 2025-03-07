#!/bin/bash
# local-validate.sh
# Script to validate code changes locally before pushing to GitHub
# Usage: ./local-validate.sh [--full]

set -e

echo "🔍 HDR+ Swift Local Validation"
echo "=============================="

# Parse arguments
FULL_CHECK=false
for arg in "$@"; do
  if [ "$arg" == "--full" ]; then
    FULL_CHECK=true
  fi
done

# Make sure the script is run from the project root
if [ ! -f "Package.swift" ] && [ ! -f "*.xcodeproj/project.pbxproj" ]; then
  echo "❌ Error: Please run this script from the project root directory"
  exit 1
fi

echo "⏳ Checking for tools..."

# Check for required tools
command -v swiftlint >/dev/null 2>&1 || { echo "❌ SwiftLint is required but not installed. Run 'brew install swiftlint'"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ Git is required but not installed."; exit 1; }

if $FULL_CHECK; then
  command -v swift >/dev/null 2>&1 || { echo "❌ Swift is required but not installed."; exit 1; }
  command -v xcodebuild >/dev/null 2>&1 || { echo "❌ Xcode Command Line Tools are required but not installed."; exit 1; }
fi

# Get list of changed files
echo "📝 Checking for modified files..."
CHANGED_FILES=$(git diff --name-only --cached | grep -E '\.swift$' || echo "")

if [ -z "$CHANGED_FILES" ]; then
  echo "ℹ️  No Swift files have been staged for commit."
  
  # Check if there are any unstaged Swift changes
  UNSTAGED_FILES=$(git diff --name-only | grep -E '\.swift$' || echo "")
  if [ -n "$UNSTAGED_FILES" ]; then
    echo "⚠️  You have unstaged Swift changes. Consider staging them with 'git add'."
  fi
else
  echo "🔍 Found $(echo "$CHANGED_FILES" | wc -l | tr -d ' ') Swift files to check."
fi

# Validate PR title format for the current branch
BRANCH_NAME=$(git branch --show-current)
if [[ "$BRANCH_NAME" =~ ^(feat|fix|docs|style|refactor|perf|test|chore)/ ]]; then
  echo "✅ Branch name follows conventional format: $BRANCH_NAME"
else
  echo "⚠️  Branch name doesn't follow conventional format (e.g., feat/feature-name): $BRANCH_NAME"
fi

# Run SwiftLint on changed files
if [ -n "$CHANGED_FILES" ]; then
  echo "🧹 Running SwiftLint on changed files..."
  swiftlint lint --quiet $(echo "$CHANGED_FILES") || {
    echo "❌ SwiftLint found issues. Please fix them before committing."
    exit 1
  }
  echo "✅ SwiftLint passed"
fi

# Check for Swift format if SwiftFormat is installed
if command -v swiftformat >/dev/null 2>&1; then
  if [ -n "$CHANGED_FILES" ]; then
    echo "🧼 Checking Swift format on changed files..."
    swiftformat --lint $(echo "$CHANGED_FILES") || {
      echo "❌ SwiftFormat found issues. Run 'swiftformat .' to fix them."
      exit 1
    }
    echo "✅ SwiftFormat passed"
  fi
else
  echo "⚠️  SwiftFormat is not installed. Consider installing it with 'brew install swiftformat'"
fi

# Full check includes building and testing
if $FULL_CHECK; then
  echo "🏗️  Running full validation check..."
  
  # Check for Swift Package Manager
  if [ -f "Package.swift" ]; then
    echo "📦 Building Swift package..."
    swift build || {
      echo "❌ Swift build failed"
      exit 1
    }
    echo "✅ Swift build passed"
    
    echo "🧪 Running tests..."
    swift test || {
      echo "❌ Tests failed"
      exit 1
    }
    echo "✅ Tests passed"
  
  # Check for Xcode project
  elif [ -d "*.xcodeproj" ]; then
    echo "🏗️  Building Xcode project..."
    xcodebuild -scheme "$(ls *.xcodeproj | sed 's/\.xcodeproj//')" clean build -quiet || {
      echo "❌ Xcode build failed"
      exit 1
    }
    echo "✅ Xcode build passed"
    
    echo "🧪 Running tests..."
    xcodebuild -scheme "$(ls *.xcodeproj | sed 's/\.xcodeproj//')" test -quiet || {
      echo "❌ Tests failed"
      exit 1
    }
    echo "✅ Tests passed"
  fi
fi

# Check for large files
echo "📏 Checking for large files..."
git diff --staged --name-only | while read file; do
  if [ -f "$file" ]; then
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ $size -gt 5000000 ]; then
      echo "⚠️  Warning: $file is $(($size / 1000000))MB, which is quite large for a git repository"
    fi
  fi
done

echo "🎉 All checks passed! Your code is ready to be committed."
echo "   For a full validation including build and tests, run with --full flag." 