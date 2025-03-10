# Code Quality Workflows

This directory contains workflows related to improving code quality and development efficiency.

## Flaky Test Detection

**Workflow file:** `test-stability.yml`

This workflow analyzes test results across multiple CI runs to identify tests that behave inconsistently (flaky tests).

### Features


- Automatically detects tests that pass in some runs but fail in others
- Generates detailed reports with failure information
- Comments on PRs when flaky tests are detected
- Maintains a list of known flaky tests for future reference

### Usage

This workflow runs automatically after each CI run. No manual action is required.

## Swift Compiler Warning Tracker

**Workflow file:** `warning-tracker.yml`

This workflow tracks Swift compiler warnings over time, helping to reduce technical debt.

### Features


- Identifies all compiler warnings in the codebase
- Groups warnings by file and type
- Tracks warning trends over time
- Identifies new warnings introduced in PRs
- Posts detailed warning reports on PRs that introduce new warnings

### Usage

This workflow runs automatically on PRs and pushes to main. You can also trigger it manually from the Actions tab.

## Build Time Analyzer

**Workflow file:** `build-time-analyzer.yml`

This workflow analyzes Swift compilation times and provides optimization suggestions.

### Features


- Identifies the slowest files and functions to compile
- Provides specific optimization suggestions for improving build times
- Creates detailed reports with timing information
- Comments on PRs that modify the build system with performance analysis

### Usage

This workflow runs weekly and on PRs that modify the build system. You can also trigger it manually.

## Benefits

These workflows provide several benefits:

1. **Reduced Debugging Time:** Flaky test detection helps identify unreliable tests early
2. **Improved Code Quality:** Warning tracking encourages cleaner code
3. **Faster Builds:** Build time analysis helps optimize compilation speeds
4. **Better Developer Experience:** Automatic comments on PRs provide immediate feedback

## Implementation Notes

These workflows are designed to be:

- **Lightweight:** They don't add significant overhead to CI times
- **Informative:** They provide actionable insights rather than just data
- **Developer-friendly:** They integrate with GitHub's PR workflow for immediate feedback
- **Low-maintenance:** They work autonomously without requiring manual intervention
