# HDR+ Swift Test Suite

This directory contains the test suite for the HDR+ Swift project, organized by test category.

## Test Categories

The test suite is organized into the following categories:

### 1. Unit Tests
Located in `UnitTests/` directory. These tests verify individual components in isolation.

- `CoreTests/` - Tests for core processing algorithms
- `UtilsTests/` - Tests for utility functions
- `IOTests/` - Tests for image input/output functions

### 2. Integration Tests
Located in `IntegrationTests/` directory. These tests verify how components work together.

- `AlignmentPipelineTests/` - Tests for the image alignment pipeline
- `MergePipelineTests/` - Tests for the image merging pipeline
- `EndToEndTests/` - Tests for complete processing chains

### 3. Visual Tests
Located in `VisualTests/` directory. These tests verify visual output quality.

- `ReferenceComparisons/` - Tests comparing outputs to reference images
- `VisualRegressionTests/` - Tests checking for visual regressions

### 4. Performance Tests
Located in `PerformanceTests/` directory. These tests measure performance metrics.

- `BenchmarkTests/` - Tests for core algorithm performance
- `MemoryTests/` - Tests for memory usage

### 5. Metal Tests
Located in `MetalTests/` directory. These tests verify Metal GPU code.

- `ShaderTests/` - Tests for Metal shader functions
- `MetalPipelineTests/` - Tests for Metal compute pipelines

## Running Tests

Tests can be run using:

1. Xcode Test navigator
2. Command line: `swift test` or `xcodebuild test`
3. CI pipeline: Automatically runs on pull requests

## Adding New Tests

Follow these guidelines when adding new tests:

1. Place tests in the appropriate category directory
2. Follow the naming convention: `[Feature]Tests.swift`
3. Use descriptive test method names: `test_[Feature]_[Scenario]_[ExpectedResult]()`
4. Include test data in the `TestResources/` directory
5. Document any special test requirements in test file header comments

## Test Resources

The `TestResources/` directory contains:

- Reference images for comparison
- Test input data
- Mock objects and fixtures

## Test Reporting

Test results are automatically collected in CI and available in:

1. GitHub Actions test summary
2. Pull request comments (for PR builds)
3. Test history dashboard 