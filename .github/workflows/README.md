# HDR+ Swift CI/CD System

This document provides an overview of the CI/CD system for HDR+ Swift, including descriptions of all workflows, best practices, and troubleshooting information.

## Workflow Categories

### Core Workflows

These workflows handle the primary build, test, and release processes:

- **[main.yml](./main.yml)**: Main CI workflow for building and testing on push/PR
- **[release.yml](./release.yml)**: Release workflow for creating and publishing releases
- **[release-candidate.yml](./release-candidate.yml)**: Release candidate validation workflow

### Code Quality Workflows

These workflows focus on code quality, linting, and style enforcement:

- **[warning-tracker.yml](./warning-tracker.yml)**: Tracks Swift compiler warnings over time
- **[test-stability.yml](./test-stability.yml)**: Identifies flaky tests that pass/fail inconsistently
- **[build-time-analyzer.yml](./build-time-analyzer.yml)**: Analyzes build times and suggests optimizations
- **[code-coverage.yml](./code-coverage.yml)**: Generates and tracks code coverage metrics

### Performance & Size Workflows

These workflows monitor performance and binary size:

- **[performance.yml](./performance.yml)**: Runs and tracks performance benchmarks
- **[performance-benchmarks.yml](./performance-benchmarks.yml)**: Detailed performance benchmarks
- **[binary-size.yml](./binary-size.yml)**: Tracks binary size changes over time

### Security Workflows

These workflows focus on security scanning and dependency analysis:

- **[security.yml](./security.yml)**: Main security scanning workflow
- **[dependency-scan.yml](./dependency-scan.yml)**: Scans dependencies for vulnerabilities
- **[dependency-updates.yml](./dependency-updates.yml)**: Checks for available dependency updates

### Documentation & Visualization

These workflows focus on documentation and dashboards:

- **[documentation.yml](./documentation.yml)**: Builds and verifies documentation
- **[dashboard.yml](./dashboard.yml)**: Builds the CI dashboard
- **[ci-dashboard.yml](./ci-dashboard.yml)**: Updates the CI metrics dashboard

### Maintenance Workflows

These workflows handle repository and workflow maintenance:

- **[maintenance.yml](./maintenance.yml)**: General repository maintenance tasks
- **[cleanup-artifacts.yml](./cleanup-artifacts.yml)**: Cleans up old workflow artifacts
- **[stale-management.yml](./stale-management.yml)**: Manages stale issues and PRs
- **[pr-labeler.yml](./pr-labeler.yml)**: Automatically labels PRs based on content

### Specialized Workflows

These workflows handle specific scenarios:

- **[cross-platform.yml](./cross-platform.yml)**: Tests on multiple platforms
- **[orchestrator.yml](./orchestrator.yml)**: Coordinates multiple workflows
- **[scheduled.yml](./scheduled.yml)**: Scheduled maintenance tasks
- **[swift-setup.yml](./swift-setup.yml)**: Reusable workflow for Swift setup
- **[config.yml](./config.yml)**: Configuration management workflow

## Shared Components (Actions)

We use several reusable composite actions to share functionality across workflows:

- **[optimized-swift-setup](../.github/actions/optimized-swift-setup)**: Sets up Swift with optimized caching
- **[test-results-visualizer](../.github/actions/test-results-visualizer)**: Visualizes test results
- **[install-brew-package](../.github/actions/install-brew-package)**: Installs and caches Homebrew packages

## Workflow Triggers

| Workflow | Push | PR | Schedule | Manual | Other |
|----------|------|----|---------:|-------:|-------|
| main.yml | ✅ | ✅ | ❌ | ✅ | ❌ |
| release.yml | ❌ | ❌ | ❌ | ✅ | Tags |
| warning-tracker.yml | ✅ | ✅ | ❌ | ✅ | ❌ |
| test-stability.yml | ❌ | ❌ | ❌ | ❌ | After CI |
| security.yml | ✅ | ✅ | ✅ | ✅ | ❌ |
| performance.yml | ✅ | ✅ | ❌ | ✅ | ❌ |
| documentation.yml | ✅ | ✅ | ❌ | ✅ | ❌ |
| build-time-analyzer.yml | ❌ | ✅* | ✅ | ✅ | ❌ |
| cleanup-artifacts.yml | ❌ | ❌ | ✅ | ✅ | ❌ |

*Only on specific file changes

## Path-Based Filtering

Many workflows use path-based filtering to optimize when they run:

- Code-only changes: `burstphoto/**`
- Documentation changes: `docs/**`, `**/*.md`
- Dependency changes: `Package.swift`, `**/*.xcodeproj`
- CI changes: `.github/workflows/**`, `.github/actions/**`

## Best Practices

### When to Use Each Workflow

1. **Main Build & Test** (`main.yml`):
   - This runs automatically on PRs and pushes to main
   - Manually trigger when testing general functionality

2. **Code Quality Checks**:
   - `warning-tracker.yml`: Runs automatically; check its reports when investigating warning issues
   - `test-stability.yml`: Automatically runs after the main workflow; check results for flaky tests
   - `build-time-analyzer.yml`: Manually trigger when investigating slow builds

3. **Performance Monitoring**:
   - `performance.yml` and `binary-size.yml`: Automatically run on PRs to catch regressions
   - `performance-benchmarks.yml`: Manually trigger for detailed performance analysis

### Debugging Failed Workflows

1. Check the workflow logs for specific error messages
2. For setup issues, try manually triggering the workflow with a clean cache
3. For test failures, look at the test-results-visualizer output
4. For inconsistent/flaky failures, check the test-stability reports

### Workflow Timeouts

Workflows have timeout limits to prevent hanging:
- Standard workflows: 30 minutes
- Complex build workflows: 45 minutes
- Performance tests: 60 minutes

If a workflow times out:
1. Check if it's a temporary resource issue
2. Consider optimizing the workflow for speed
3. For legitimate long-running tasks, adjust the timeout limit

## Common CI Issues and Solutions

| Issue | Possible Causes | Solutions |
|-------|----------------|-----------|
| Cache miss | New branch, modified dependencies | Wait for first run to complete |
| Swift version mismatch | Xcode update, version conflict | Specify swift-version input |
| Code signing errors | Certificates not available | Ensure disable-code-signing is enabled |
| Flaky tests | Timing-dependent tests, resource issues | Check test-stability reports |
| Slow builds | Large Swift files, type checking | Check build-time-analyzer reports |

## Extending the CI System

When adding new workflows:

1. **Use existing patterns**: Follow the structure of similar workflows
2. **Leverage shared actions**: Use optimized-swift-setup and other shared actions
3. **Add path filters**: Only run when relevant files change
4. **Add timeouts**: Always include job-level timeout limits
5. **Document**: Add your workflow to this README

## Contributing

Improvements to the CI system are welcome! Please consider:

1. Making workflows faster
2. Reducing duplication across workflows
3. Improving error handling and resilience
4. Adding useful metrics and visualizations

When submitting CI changes, ensure:
- Changes don't break existing workflows
- New features are documented
- Timeouts and retry strategies are appropriate 