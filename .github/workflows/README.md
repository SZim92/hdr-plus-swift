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
- **[retry-utility.yml](./retry-utility.yml)**: Utility for running tests with automatic retries
- **[ci-health-check.yml](./ci-health-check.yml)**: Weekly scan for CI health issues and outdated actions

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

## CI Troubleshooting and Best Practices

### GitHub Pages Deployment

Our GitHub Pages workflows use direct Git deployment instead of the standard GitHub Pages actions due to potential artifact-related issues. This approach:

- **Eliminates action dependencies**: Avoids issues with deprecated artifact actions
- **Provides more reliable deployments**: Reduces points of failure in the deployment process
- **Gives us more control**: Customizable deployment with direct Git access

Example implementation:
```yaml

- name: Deploy directly to gh-pages branch
  run: |
    git config --global user.name "GitHub Actions"
    git config --global user.email "actions@github.com"
    
    # Create and navigate to a clean deploy directory
    rm -rf /tmp/gh-pages-deploy
    mkdir -p /tmp/gh-pages-deploy
    cp -r your-content/* /tmp/gh-pages-deploy/
    cd /tmp/gh-pages-deploy
    
    # Initialize git and create a commit
    git init
    git add .
    git commit -m "Deploy from ${{ github.sha }}"
    git branch -M main
    
    # Force push to gh-pages branch
    git push -f https://x-access-token:${{ github.token }}@github.com/${{ github.repository }}.git main:gh-pages
```

### Swift and Xcodebuild Robustness

Swift and Xcodebuild can fail in unexpected ways in CI environments. Our workflows include:

- **Pre-build verification**: Check if xcodebuild is working before running builds
- **Avoid pipe redirections**: Write build output directly to files instead of using `tee`
- **Multiple fallbacks**: Have fallback mechanisms for when tools fail
- **Comprehensive logging**: Generate useful reports even when builds fail

Example of robust xcodebuild usage:
```yaml

# Write directly to log file instead of using tee (which can cause broken pipes)

xcodebuild build \

  -project MyProject.xcodeproj \
  -scheme MyScheme \
  -destination "platform=macOS" \

  > build.log 2>&1 || echo "Build exited with non-zero status"
```

### Job Outputs vs. Artifacts

For passing data between jobs:

- **Job outputs**: Use for small data (<1MB) like status flags, paths, or configuration values
- **Artifacts**: Use for larger files (build products, reports, logs) 

Example of job outputs:
```yaml
jobs:
  generate-data:
    outputs:
      result: ${{ steps.my-step.outputs.result }}
    steps:

      - id: my-step
        run: echo "result=some-value" >> $GITHUB_OUTPUT
        
  use-data:
    needs: generate-data
    steps:

      - run: echo "Using ${{ needs.generate-data.outputs.result }}"
```

### Regular CI Health Checks

The `ci-health-check.yml` workflow runs weekly to:

- Scan all workflow files for outdated action versions
- Identify deprecated command patterns
- Check for best practices like timeouts and error handling
- Generate a comprehensive health report

Regularly review these reports to keep your CI system healthy and avoid surprises from deprecated features.

### Handling Flaky Tests

Flaky tests can be a significant problem in CI environments. We provide two approaches:

1. **Test Stability Tracking**: The `test-stability.yml` workflow tracks tests that pass in some runs but fail in others, identifying potential flaky tests.

2. **Automated Retries**: The `retry-utility.yml` workflow provides a pattern for automatically retrying flaky tests:

```yaml

# Example of using retry logic in a workflow


- name: Run tests with retry
  run: |
    MAX_ATTEMPTS=3
    ATTEMPT=1
    SUCCESS=false
    
    while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$SUCCESS" = "false" ]; do
      echo "Test attempt $ATTEMPT of $MAX_ATTEMPTS"
      
      if your-test-command; then
        echo "Tests passed on attempt $ATTEMPT"
        SUCCESS=true
      else
        echo "Tests failed on attempt $ATTEMPT"
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
          echo "Retrying in 10 seconds..."
          sleep 10
        fi
      fi
      
      ATTEMPT=$((ATTEMPT + 1))
    done
    
    if [ "$SUCCESS" = "false" ]; then
      echo "All $MAX_ATTEMPTS attempts failed"
      exit 1
    fi
```

You can also invoke the retry-utility workflow directly for specific tests that need retries.

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

# GitHub Actions Workflows

## Core Workflows

- **[main.yml](./main.yml)**: Primary CI workflow for building and testing
- **[maintenance.yml](./maintenance.yml)**: Manages readme badges and repository maintenance
- **[documentation.yml](./documentation.yml)**: Generates and deploys documentation
- **[release.yml](./release.yml)**: Creates releases with artifacts

## Specialized Workflows

- **[retry-utility.yml](./retry-utility.yml)**: Utility for running tests with automatic retries
- **[ci-health-check.yml](./ci-health-check.yml)**: Weekly scan for CI health issues and outdated actions
- **[build-time-analyzer.yml](./build-time-analyzer.yml)**: Analyzes build performance
- **[scheduled.yml](./scheduled.yml)**: Runs weekly maintenance tasks
- **[test-stability.yml](./test-stability.yml)**: Tracks flaky tests
- **[warning-tracker.yml](./warning-tracker.yml)**: Tracks Swift compiler warnings

## Utility Workflows

- **[cleanup-artifacts.yml](./cleanup-artifacts.yml)**: Removes old workflow artifacts
- **[stale-management.yml](./stale-management.yml)**: Manages stale issues and PRs
- **[swift-setup.yml](./swift-setup.yml)**: Reusable workflow for Swift environment setup
- **[artifact-test.yml](./artifact-test.yml)**: Example workflow using job outputs instead of artifacts
- **[orchestrator.yml](./orchestrator.yml)**: Coordinates running multiple workflows

## Troubleshooting

### Running Jobs Locally

For testing workflows locally before committing, use [act](https://github.com/nektos/act):

```bash

# Install act

brew install act

# Run a specific workflow

act -W .github/workflows/main.yml

# Run a specific job

act -W .github/workflows/main.yml -j lint
```

### Handling Flaky Tests

Flaky tests (tests that sometimes pass and sometimes fail) can be addressed using two approaches:

#### 1. Test Stability Tracking

The `test-stability.yml` workflow tracks test stability across multiple runs to identify flaky tests automatically. When flaky tests are detected, they are reported in PR comments and logged for future reference.

#### 2. Automated Retries

For known flaky tests, you can use the `retry-utility.yml` workflow or implement retry logic directly in your workflows:

```yaml

- name: Run tests with retry
  run: |
    MAX_ATTEMPTS=3
    ATTEMPT=1
    SUCCESS=false
    
    while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$SUCCESS" = "false" ]; do
      echo "Test attempt $ATTEMPT of $MAX_ATTEMPTS"
      
      if xcodebuild test -scheme YourScheme -destination "platform=macOS"; then
        echo "Tests passed on attempt $ATTEMPT"
        SUCCESS=true
      else
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
          echo "All $MAX_ATTEMPTS attempts failed"
          exit 1
        else
          echo "Retrying in 10 seconds..."
          sleep 10
        fi
      fi
      
      ATTEMPT=$((ATTEMPT + 1))
    done
```

## Best Practices

1. **Timeouts**: Always set `timeout-minutes` on jobs to prevent stuck workflows
2. **Path Filtering**: Use `paths` filters to only run workflows when relevant files change
3. **Caching**: Utilize `actions/cache` to speed up builds
4. **Self-Hosted Runners**: Consider self-hosted runners for faster macOS builds
5. **Matrix Builds**: Use matrix strategy for testing on multiple platforms/configurations
