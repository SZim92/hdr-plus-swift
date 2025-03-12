# HDR+ Swift Test Framework Guide

This document provides a comprehensive guide to using the test framework in the HDR+ Swift project. It covers the available test scripts, utilities, and best practices for testing.

## Test Scripts

The HDR+ Swift project includes several test scripts to facilitate different types of testing:

### 1. Main Test Runner (`Scripts/run-tests.sh`)

This script is the primary tool for running tests. It supports various test types, configurations, and reporting options.

```bash
# Run all tests
./Scripts/run-tests.sh

# Run only unit tests with verbose output
./Scripts/run-tests.sh --unit --verbose

# Run tests with a specific filter
./Scripts/run-tests.sh --filter "AlignmentTests"

# Generate test coverage
./Scripts/run-tests.sh --coverage

# Run on a specific device
./Scripts/run-tests.sh --device "iPhone 14 Pro"
```

Key options:
- `--unit`: Run unit tests
- `--integration`: Run integration tests
- `--visual`: Run visual tests
- `--performance`: Run performance tests
- `--all`: Run all tests (default)
- `--verbose`: Enable verbose output
- `--filter <pattern>`: Filter tests by name pattern
- `--device <device>`: Specify test device/platform
- `--retry <count>`: Retry flaky tests
- `--coverage`: Generate test coverage
- `--html-report`: Generate HTML test report
- `--json-report`: Generate JSON test report
- `--no-retry`: Disable retry for flaky tests

### 2. Integration Test Runner (`Scripts/run-integration-tests.sh`)

This script focuses specifically on integration tests, providing more specialized options for testing component interactions:

```bash
# Run all integration tests
./Scripts/run-integration-tests.sh

# Run specific integration test suite
./Scripts/run-integration-tests.sh --test "HDRPipelineIntegrationTests"

# Run with longer timeout for complex tests
./Scripts/run-integration-tests.sh --timeout 600
```

Key options:
- `--test <regex>`: Run tests matching pattern
- `--skip <regex>`: Skip tests matching pattern
- `--timeout <seconds>`: Set test timeout
- `--retry <count>`: Number of retries for failed tests
- `--fail-fast`: Stop after first failure
- `--env <environment>`: Set test environment
- `--no-report`: Disable report generation
- `--format <format>`: Report format (html, junit, json)
- `--coverage`: Include coverage information
- `--destination <destination>`: Xcode destination

### 3. Generate Test Data (`Scripts/generate-test-data.sh`)

This script generates test data for use in tests:

```bash
# Generate standard test data set
./Scripts/generate-test-data.sh

# Generate specific test data
./Scripts/generate-test-data.sh --type hdr
```

## Test Utilities

The project includes several test utilities to simplify test writing and execution:

### 1. TestHelper

The `TestHelper` utility provides common functionality for all test types:

```swift
// Load test resources
let data = TestHelper.loadResource(named: "test_image", extension: "jpg")

// Create temporary files
let tempURL = try TestHelper.createTemporaryFile(data: imageData, extension: "jpg")

// Assert equality with tolerance
TestHelper.assertEqual(array1, array2, tolerance: 0.001)

// Wait for condition with timeout
try TestHelper.waitFor(condition: { isProcessingComplete }, timeout: 5.0)

// Measure execution time
let time = TestHelper.measureExecutionTime {
    processor.processImage(input)
}

// Measure memory usage
let memoryMB = TestHelper.measureMemoryUsage {
    processor.processImage(input)
}
```

### 2. TestConfig

The `TestConfig` utility provides centralized configuration for tests:

```swift
// Check if running in CI environment
if TestConfig.shared.isCI {
    // Skip long-running test in CI
}

// Check if verbose logging is enabled
if TestConfig.shared.verboseLogging {
    print("Detailed test information...")
}

// Access test resources directory
let resourceURL = TestConfig.shared.resourcesDirectory.appendingPathComponent("images")

// Check performance settings
let timeout = TestConfig.shared.performanceSettings.defaultTimeout
let deviation = TestConfig.shared.performanceSettings.allowedDeviation
```

### 3. ParameterizedTestUtility

The `ParameterizedTestUtility` supports data-driven testing:

```swift
// Run tests with input/output pairs
ParameterizedTestUtility.runTest(
    inputs: [input1, input2, input3],
    expectedOutputs: [expected1, expected2, expected3]
) { input in
    return processor.process(input)
}

// Run tests with named test cases
let testCases = [
    NamedTestCase(name: "Low exposure", input: lowExposureImage, expected: processedLowExposure),
    NamedTestCase(name: "High exposure", input: highExposureImage, expected: processedHighExposure)
]
ParameterizedTestUtility.runTest(cases: testCases) { input in
    return processor.process(input)
}

// Load test cases from JSON file
let testCases = try ParameterizedTestUtility.loadTestCases(
    fromJSON: "exposure_test_cases.json",
    inputKey: "input_image",
    expectedKey: "expected_result"
)
```

### 4. MetalTestUtility

The `MetalTestUtility` facilitates testing Metal code:

```swift
// Skip test if Metal is not available
guard let metalUtil = try? MetalTestUtility() else {
    XCTSkipIf(true, "Metal is not available")
    return
}

// Create buffers for Metal testing
let inputBuffer = try metalUtil.createBuffer(from: inputData)
let outputBuffer = try metalUtil.createEmptyBuffer(size: outputSize)

// Create compute pipeline
let pipeline = try metalUtil.createComputePipeline(function: "processImage")

// Run compute shader
try metalUtil.runComputeShader(
    pipeline: pipeline,
    inputBuffers: [inputBuffer],
    outputBuffer: outputBuffer,
    threadGroupSize: MTLSize(width: 16, height: 16, depth: 1),
    threadGroups: MTLSize(width: width/16, height: height/16, depth: 1)
)

// Verify results
let results = try metalUtil.extractDataFromBuffer(outputBuffer, type: Float.self)
try metalUtil.verifyEqual(results, expectedResults, tolerance: 0.001)
```

### 5. TestQuarantine

The `TestQuarantine` utility helps manage flaky tests:

```swift
class MyFlakyTests: XCTestCase {
    // Mark test as quarantined with reason
    @TestQuarantine(reason: "Fails intermittently when network is slow", 
                    ticketID: "HDR-123",
                    failureRate: 0.2)
    func testNetworkOperation() {
        // Test implementation
    }
    
    // Mark test to be skipped in CI but run locally
    @TestQuarantine(skipInCI: true, 
                    reason: "Resource intensive test not suitable for CI",
                    ticketID: "HDR-456")
    func testResourceIntensiveOperation() {
        // Test implementation
    }
}
```

## Test Template

The project includes a `TestTemplate.swift` file that demonstrates best practices for writing tests. Use this template as a starting point for new test classes.

## Best Practices

1. **Test Organization**:
   - Place unit tests in the `UnitTests` directory
   - Place integration tests in the `IntegrationTests` directory
   - Place visual tests in the `VisualTests` directory
   - Place performance tests in the `PerformanceTests` directory

2. **Test Naming**:
   - Name test classes with a suffix of `Tests` (e.g., `AlignmentTests`)
   - Name test methods with a prefix of `test` followed by what you're testing and the expected behavior (e.g., `testAlignmentWithLowLight_ShouldAlignCorrectly`)

3. **Test Data**:
   - Place test data in the `TestResources` directory
   - Use the `TestHelper` to load test resources
   - Generate test data programmatically when possible to reduce repository size

4. **Test Independence**:
   - Each test should be independent and not rely on the state from previous tests
   - Use `setUp()` and `tearDown()` methods to initialize and clean up resources

5. **Performance Testing**:
   - Use the `TestHelper.measureExecutionTime` method for consistent timing
   - Set baseline performance expectations and allow for reasonable deviation
   - Skip performance tests in CI environments when appropriate

6. **Metal Testing**:
   - Always check if Metal is available before running Metal tests
   - Use the `MetalTestUtility` for consistent Metal testing
   - Skip Metal tests on devices without Metal support

7. **Flaky Tests**:
   - Use `@TestQuarantine` to mark and manage flaky tests
   - Create tickets to track and fix flaky tests
   - Regularly review the flaky test report to identify patterns

## CI Integration

The test framework is integrated with CI through GitHub Actions workflows:

- `main.yml`: Runs all tests for pull requests and merges to main
- `test-quarantine.yml`: Analyzes test stability and updates quarantine status

Tests that consistently fail in CI will be automatically marked for quarantine, and a GitHub issue will be created to track the problem.

## Troubleshooting

If you encounter issues with the test framework:

1. Check the test logs in the `TestResults` directory
2. Run tests with the `--verbose` flag for more detailed output
3. Ensure your environment is properly set up (Xcode, Metal support, etc.)
4. Check for known issues in the GitHub issue tracker

For specific test failures:
1. Isolate the failing test with the `--filter` option
2. Run the test with verbose logging and debugging enabled
3. Check if the test is marked as flaky in the quarantine system 