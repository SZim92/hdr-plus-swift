# HDR+ Swift CI Architecture

This document describes the modernized CI/CD pipeline for the HDR+ Swift project.

## Architecture Overview

![CI Architecture](https://mermaid.ink/img/pako:eNp1kU9PwzAMxb9K5BMgpO0AEofOErQDEwckJA5cQpsmW0KTKE5hU9R-d9IWbQMmH_L8_kq2n0WpNQpXDH3X2oaaIJSlJXQU75jCmEO04aNV3bAxLrZZcmEYB5TkO5LuNQ06zz2KDtWFYXxOqSrTp1p5fECtvEMIzI8A93k1PjsYogzwmh7GzWgEH1Ao8kAKG1H2rYIQVZQBXPPAjNx5Yqeh9GDo1GJl9cRuIcnq27fVnGKdFrJYI1nQvlBtE5KtZbcjC9Mf_mT2o4V7MK2vHPrJlvRU9tHOlBBZTzU1veMwLVrz8_p2Mmd8PfGTkgqRBK0ijdVENZNsP1oU7qMO-Sz_HrP8ItuhBTfWaVyG5Xrx-5CIFp2Y3R_3H0EW)

The CI pipeline consists of these key components:

1. **Configuration Layer**: Central configuration for all workflows
2. **Reusable Workflows**: Shared, reusable workflow components
3. **Main CI Pipeline**: Entry point that orchestrates the process
4. **Helper Scripts**: Utility scripts for specialized tasks
5. **Reporting Layer**: Consolidated test results and diagnostics

## Configuration-Driven Approach

All CI settings are centralized in `ci-config.yml`, making it easy to:
- Add or remove test platforms
- Adjust caching strategies
- Configure test timeouts and retry logic
- Define build optimization settings

## Reusable Workflows

The modernized CI system uses reusable workflows to avoid duplication:

### Metal Testing Workflow

This workflow handles all Metal-specific testing across platforms:
- Detects Metal capabilities on the runner
- Sets up appropriate environment variables
- Collects diagnostics for debugging
- Runs tests with proper Metal configuration
- Archives results and logs

### Test Summarizer Workflow

This workflow creates comprehensive test summaries:
- Aggregates results from all platforms
- Generates formatted reports
- Highlights issues and failures
- Provides platform-specific context

## Integrating with Existing Workflows

The modernized CI components are designed to coexist with existing workflows:

- **Security Scanning**: Enhanced with Metal-aware security checks
- **Release Process**: Maintains compatibility with the release workflow
- **PR Validation**: Integrates with PR checks and labeling
- **Cross-Platform Testing**: Works alongside specialized platform tests

## Platform Matrix Support

The CI system supports testing across various macOS platforms:

| Platform | Architecture | Xcode Version | Metal Support |
|----------|--------------|---------------|--------------|
| macOS Sonoma | Apple Silicon (arm64) | 15.2 | Full |
| macOS Ventura | Intel (x86_64) | 15.0 | Full |

## Advanced Features

### Parallel Testing

Tests run in parallel across platforms using GitHub Actions matrix strategy:
- Separate jobs for each platform
- Fail-fast disabled to ensure complete results
- Consolidated reporting regardless of failures

### Dependency Caching

Optimized caching strategy for Swift packages:
- Caches are keyed by platform and architecture
- Hash-based invalidation using package dependencies
- Hierarchical fallback for partial hits

### Metal Diagnostics

Comprehensive Metal diagnostics collection:
- System information gathering
- GPU capability detection
- Metal framework availability testing
- Diagnostic logging for troubleshooting

## Implementation Guides

### Adding a New Test Platform

To add a new test platform:

1. Edit `.github/workflows/shared/ci-config.yml`
2. Add a new entry to the platform matrix
3. Specify runner, Xcode version, and architecture

Example:
```yaml
- name: "macOS Monterey (Intel)"
  runner: "macos-12"
  xcode: "14.2"
  architecture: "x86_64"
```

### Creating a Custom Test Configuration

To create a specialized test configuration:

1. Create a new workflow file in `.github/workflows/shared/`
2. Define inputs for platform-specific parameters
3. Set up the `workflow_call` trigger
4. Reference the workflow from main.yml

## Best Practices

1. **Incremental Testing**: Use the platform filter to test specific platforms during development
2. **Metal Testing**: Be aware that Metal tests may not run properly in CI environments
3. **Caching**: Keep cache key definitions consistent across workflows
4. **Timeouts**: Set appropriate timeouts for each job type
5. **Dependencies**: Ensure cross-job dependencies are properly defined

## Troubleshooting

### Common Issues

1. **Metal Tests Failing**: Metal tests often fail in CI environments due to GPU limitations
   - Solution: Use the Metal diagnostics to understand the failure
   - Consider adding conditional logic to skip GPU-intensive tests in CI

2. **Cache Misses**: Frequent cache misses can slow down the CI
   - Solution: Check that cache keys are consistent
   - Ensure paths are correctly specified in the cache configuration

3. **Missing Results**: Sometimes test results aren't properly collected
   - Solution: Check the test summarizer's artifact path configuration
   - Ensure tests generate results in the expected location 