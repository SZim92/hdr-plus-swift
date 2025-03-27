# CI Guide for HDR+ Swift Developers

This document provides guidance for developers working with the HDR+ Swift CI system.

## Table of Contents

- [Understanding the CI System](#understanding-the-ci-system)
- [Working with Pull Requests](#working-with-pull-requests)
- [Interpreting Test Results](#interpreting-test-results)
- [Metal Testing in CI](#metal-testing-in-ci)
- [Workflow Customization](#workflow-customization)
- [Troubleshooting](#troubleshooting)

## Understanding the CI System

The HDR+ Swift CI system is designed to be:

1. **Modular**: Composed of separate components for flexibility
2. **Platform-aware**: Tests on multiple macOS versions and architectures
3. **Metal-ready**: Includes special support for testing Metal code
4. **Developer-friendly**: Provides detailed feedback on test results

The system automatically tests your code when you:
- Push to the main branch
- Create or update a pull request
- Manually trigger the workflow

## Working with Pull Requests

### CI Checks

When you create a pull request, several CI checks will run:

1. **Lint Check**: Verifies code style and formatting
2. **Metal Tests**: Runs tests across multiple platforms
3. **Test Summary**: Consolidates and reports test results

### PR Labels

PRs are automatically labeled based on:

- Files changed (UI, core, tests, docs, etc.)
- Size of changes (small, medium, large)
- Status of CI checks

### Test Status Comments

The CI system will automatically comment on your PR with:

- Test result summaries for each platform
- Metal testing notes (if relevant)
- Links to detailed logs

## Interpreting Test Results

Test results are presented in three formats:

1. **GitHub Checks**: Pass/fail status in the PR checks section
2. **PR Comments**: Detailed breakdown in PR comments
3. **Artifacts**: Full test logs and reports as downloadable artifacts

### Common Status Icons

- ✅ **Success**: All tests passed
- ❌ **Failure**: Some tests failed
- ⚠️ **Warning/Mixed**: Some issues were detected but may be expected

## Metal Testing in CI

### Limitations in CI Environment

Metal tests run differently in CI than locally:

- CI runners have limited GPU support
- Hardware acceleration might be unavailable
- Metal device initialization can fail in CI environments

### Interpreting Metal Test Results

When Metal tests fail in CI but work locally:

1. Check the Metal diagnostics in the test artifacts
2. Look for environment-specific issues
3. Consider conditionally skipping hardware-dependent tests in CI

### Metal Diagnostics

Each run collects Metal diagnostics including:

- GPU capabilities
- System information
- Metal framework availability
- Detailed error logs

## Workflow Customization

### Testing Specific Platforms

To test only specific platforms (e.g., during development):

1. Go to Actions → CI → Run workflow
2. Enter platforms to test (e.g., "macos-14,macos-13")
3. Run workflow

### Local Workflow Testing

To test workflows locally before pushing:

1. Install [act](https://github.com/nektos/act)
2. Run `act pull_request -W .github/workflows/main.yml`

## Troubleshooting

### Common Issues

1. **"Metal tests failing in CI but working locally"**
   - This is normal - CI environments have limited GPU support
   - Check Metal diagnostics for specific errors
   - Consider using conditional test skipping

2. **"CI workflow failing with cryptic error"**
   - Check the specific job that failed
   - Download artifacts for detailed logs
   - Look for environment setup errors

3. **"Tests passing but status check failing"**
   - This might be a reporting issue
   - Check if any platforms failed while others passed
   - Look at the PR comment for detailed status

### Getting Help

If you're having issues with the CI system:

1. Check the test artifacts for detailed logs
2. Reference the CI architecture documentation
3. Ask for help from the infrastructure team 