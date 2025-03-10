# HDR+ Swift CI Documentation

## Overview
This document provides documentation for the CI/CD system used in the HDR+ Swift project. The system is designed to build, test, and maintain the codebase with minimal intervention required.

## Core Workflows

### Main CI Workflow (main.yml)
The primary workflow that runs tests and validates the codebase.

- **Triggers**: Pull requests, pushes to main branch, and manual triggers
- **Key Jobs**: 
  - Lint: Runs SwiftLint to check code style
  - Test: Executes tests on multiple macOS versions
  - Build: Creates release builds
- **Key Features**: 
  - Smart path filtering to skip irrelevant runs
  - Caching of Swift dependencies and Homebrew
  - Concurrent job execution with dependencies

### Apple Platform Compatibility (cross-platform.yml)
Verifies the project builds correctly on supported Apple platforms.

- **Triggers**: Pull requests, pushes to main branch, scheduled runs, and manual triggers
- **Purpose**: Validates the codebase builds successfully on different macOS versions
- **Key Jobs**: 
  - Set up test matrix: Prepares the platforms to test (macOS Sonoma, Ventura)
  - Test on macOS: Builds the project and runs available tests
  - Summarize results: Collects and presents test results
- **Key Features**: 
  - Metal environment diagnostics for GPU-dependent code
  - Robust platform matrix generation with filtering options
  - Comprehensive build output and error analysis
  - Support for platform filtering via workflow dispatch
  - Handles Metal-specific limitations in CI environments

### Swift Warning Tracker (warning-tracker.yml)
Tracks Swift compiler warnings to help maintain code quality.

- **Triggers**: Scheduled runs, manual triggers, and after PRs
- **Purpose**: Identifies Swift compiler warnings, tracks them over time, and reports increases
- **Key Features**: 
  - Robust error handling for Xcode/Swift version checks
  - Fallback mechanisms to prevent broken pipe errors
  - Warning reports stored as artifacts for reference
  - Creates GitHub check annotations for warnings

### Maintenance Workflow (maintenance.yml)
Handles ongoing maintenance like README badge updates.

- **Triggers**: Pushes to main branch and manual triggers
- **Key Jobs**: 
  - update-badge: Manages the build status badge in the README
- **Key Features**: 
  - Idempotent badge management (prevents duplicate badges)
  - Skips CI on badge commits to avoid unnecessary runs

## Troubleshooting Guide

### Swift Warning Tracker Issues

**Problem**: Warning tracker fails with "broken pipe" errors during Xcode version check.

**Solution**: This has been fixed by improving how output is redirected:
1. The workflow now uses file redirection instead of pipes
2. It implements fallback mechanisms for version detection
3. It continues execution even when initial checks fail

**If it happens again**: 
- Check the Xcode version command to ensure it isn't producing excessive output
- Verify that `continue-on-error: true` is set for relevant steps

### Badge Duplication in README

**Problem**: Multiple build status badges appearing in the README.

**Solution**: The maintenance.yml workflow now:
1. Extracts content properly, skipping empty lines
2. Reconstructs the README with a clean structure
3. Uses content comparison to determine if changes are needed

**If it happens again**:
- Check the sed command in maintenance.yml that processes content
- Verify the README structure hasn't been manually altered in an incompatible way

### Cache Issues

**Problem**: Cache not working, leading to slow builds.

**Solution**:
1. Check cache keys in the workflow files
2. Verify paths being cached (especially for Xcode/Swift caches)
3. Look for cache size limits being exceeded

### Apple Platform Compatibility Issues

**Problem**: Build failures on specific macOS versions.

**Solution**:
1. Check the build output logs for specific errors
2. Verify that the correct scheme ("gui") is being targeted
3. Inspect Metal environment information for GPU/driver issues
4. Consider platform-specific conditionals for problematic code

**Problem**: "No scheme" or "Cannot find scheme" errors.

**Solution**:
1. Verify the scheme name matches exactly (case-sensitive)
2. Check if the scheme is shared (schemes should be checked into version control)
3. Run `xcodebuild -project burstphoto.xcodeproj -list` locally to verify schemes
4. The workflow now automatically lists available schemes to help with debugging

## Configuration System

HDR+ Swift uses a centralized configuration system:

### workflow-config.yml
Located at `.github/workflow-config.yml`, this file contains shared configuration values:

- **Version Information**: Project version numbers
- **Build Configuration**: Project identifiers, schemes, and artifact retention settings
- **Environment Support**: Supported macOS versions and container images
- **Repository Settings**: Branch names and patterns
- **Performance Thresholds**: Binary size limits and code coverage targets

### Using Configuration Values

The configuration is loaded by the `load-config` action and makes values available as outputs. Example:

```yaml
- name: Load configuration
  id: load-config
  uses: ./.github/actions/load-config

- name: Use configuration values
  run: |
    echo "Project: ${{ steps.load-config.outputs.project }}"
    echo "Main branch: ${{ steps.load-config.outputs.main_branch }}"
```

## Custom Actions

The repository includes several custom GitHub Actions:

### optimized-swift-setup
Sets up the Swift environment with optimized caching.

- **Location**: `.github/actions/optimized-swift-setup`
- **Key Parameters**:
  - `cache-name`: Identifier for cache
  - `disable-code-signing`: Whether to disable code signing
  - `install-swiftlint`: Whether to install SwiftLint

### load-config
Loads shared configuration values.

- **Location**: `.github/actions/load-config`
- **Outputs**: All configuration values from workflow-config.yml

## Best Practices

1. **Use the Optimized Swift Setup**: Always use this action for Swift environment setup
2. **Leverage the Load Config Action**: Access shared configuration through this action
3. **Add Error Handling**: Include fallbacks and error handling for critical steps
4. **Avoid Pipes for Large Outputs**: Use file redirection instead of pipes for large command outputs
5. **Be Explicit with Permissions**: Set minimum required permissions for each workflow 