# HDR+ Swift Testing Guidelines

This document provides guidelines, best practices, and patterns for creating effective tests for the HDR+ Swift project. Following these guidelines will help ensure test consistency, reliability, and maintainability across the project.

## Table of Contents
1. [General Testing Principles](#general-testing-principles)
2. [Test Structure](#test-structure)
3. [Test Types](#test-types)
   - [Unit Tests](#unit-tests)
   - [Integration Tests](#integration-tests)
   - [Visual Tests](#visual-tests)
   - [Performance Tests](#performance-tests)
   - [Metal Tests](#metal-tests)
4. [Using Test Utilities](#using-test-utilities)
5. [Test Data Management](#test-data-management)
6. [CI Integration](#ci-integration)
7. [Debugging Tests](#debugging-tests)
8. [Common Pitfalls](#common-pitfalls)

## General Testing Principles

### 1. Test Independence
- Each test should be independent and not rely on the state from other tests
- Tests should be able to run in any order
- Use setup and teardown methods to create a clean environment for each test

### 2. Test Clarity
- Test names should clearly describe what is being tested
- Use the AAA pattern (Arrange, Act, Assert)
- Include comments for complex test logic

### 3. Test Coverage
- Aim for comprehensive coverage of code paths
- Include edge cases and error conditions
- Test boundary conditions

### 4. Test Reliability
- Tests should yield consistent results
- Avoid flaky tests with non-deterministic behavior
- Use TestFixtureUtility to set up controlled test environments

### 5. Test Performance
- Tests should run quickly to encourage frequent execution
- Use PerformanceTestUtility for dedicated performance tests
- Mark slow tests appropriately to allow selective execution

## Test Structure

### Class Structure

```swift
import XCTest
@testable import HDRPlus

class FeatureTests: XCTestCase {
    // MARK: - Properties
    private var testFixture: TestFixtureUtility.Fixture!
    
    // MARK: - Setup/Teardown
    override func setUp() async throws {
        try await super.setUp()
        testFixture = try createFixture()
        // Additional setup...
    }
    
    override func tearDown() async throws {
        // Specific teardown...
        testFixture = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    func testFeatureWithValidInput() throws {
        // Arrange
        // ...
        
        // Act
        // ...
        
        // Assert
        // ...
    }
    
    func testFeatureWithInvalidInput() throws {
        // ...
    }
    
    // MARK: - Helper Methods
    private func helperMethod() -> Any {
        // ...
    }
}
```

### Naming Conventions

- **Test Class**: `{Feature}Tests`
- **Test Method**: `test{Scenario}_{ExpectedOutcome}`
- **Helper Method**: Descriptive name indicating its purpose

## Test Types

### Unit Tests

Unit tests verify individual components in isolation.

**Best Practices:**
- Focus on testing a single function or method
- Mock dependencies using test doubles
- Verify all code paths including error handling
- Keep tests small and focused

**Example:**

```swift
func testExposureCalculation_WithNormalInput_ReturnsCorrectValue() throws {
    // Arrange
    let iso = 100
    let shutterSpeed = 1.0/125.0
    let calculator = ExposureCalculator()
    
    // Act
    let ev = calculator.calculateEV(iso: iso, shutterSpeed: shutterSpeed)
    
    // Assert
    XCTAssertEqual(ev, 13.0, accuracy: 0.01)
}
```

### Integration Tests

Integration tests verify that multiple components work together correctly.

**Best Practices:**
- Test interactions between related components
- Use realistic test data
- Focus on the integration points
- Ensure components work together as expected

**Example:**

```swift
func testImageCaptureAndProcessing() throws {
    // Arrange
    let camera = MockCamera()
    let processor = HDRProcessor()
    let pipeline = ProcessingPipeline(camera: camera, processor: processor)
    
    // Act
    let result = try pipeline.captureAndProcessHDR(frameCount: 3)
    
    // Assert
    XCTAssertNotNil(result.finalImage)
    XCTAssertEqual(result.metadata.frameCount, 3)
    // Additional assertions...
}
```

### Visual Tests

Visual tests verify that image processing operations produce the expected visual results.

**Best Practices:**
- Use the VisualTestUtility for image comparisons
- Include reference images in the test resources
- Set appropriate tolerance values for pixel comparison
- Generate visual diffs for debugging failed tests

**Example:**

```swift
func testToneMapping_WithHighDynamicRangeImage_ProducesExpectedResult() throws {
    // Arrange
    let hdrImage = try loadTestImage("hdr_test_image")
    let toneMapper = HDRToneMapper()
    
    // Act
    let mappedImage = toneMapper.apply(to: hdrImage)
    
    // Assert
    try VisualTestUtility.compareImages(
        actual: mappedImage,
        expected: "tone_mapped_reference",
        tolerance: 0.02,
        saveDiffOnFailure: true
    )
}
```

### Performance Tests

Performance tests verify that operations meet performance requirements.

**Best Practices:**
- Use PerformanceTestUtility for consistent measurements
- Include baseline values for comparison
- Set appropriate deviation thresholds
- Test with realistic data sizes

**Example:**

```swift
func testAlignmentPerformance() throws {
    // Arrange
    let images = try loadTestImages(count: 8, size: CGSize(width: 2048, height: 1536))
    let aligner = HDRAligner()
    
    // Act & Assert
    try measureExecutionTime(
        name: "hdr_alignment_8_frames",
        baselineValue: 200.0,  // 200ms baseline
        acceptableDeviation: 0.2  // 20% deviation allowed
    ) {
        _ = try aligner.alignImages(images)
    }
}
```

### Metal Tests

Metal tests verify GPU-accelerated code works correctly.

**Best Practices:**
- Use MetalTestUtility for shader testing
- Include both functional and performance tests
- Test with different input sizes
- Verify results against CPU implementations when possible

**Example:**

```swift
func testNoiseReductionShader() throws {
    // Arrange
    let metalUtil = try createMetalTestUtility()
    let pipelineState = try metalUtil.createComputePipelineState(functionName: "denoise_shader")
    
    // Create test data
    let inputData: [Float] = createNoisyTestData(width: 512, height: 512)
    let inputBuffer = try metalUtil.createBuffer(from: inputData)
    
    let outputBuffer = try metalUtil.createBuffer(
        count: inputData.count,
        type: Float.self
    )
    
    // Act
    try metalUtil.runComputeShader2D(
        pipelineState: pipelineState,
        inputBuffers: [inputBuffer],
        outputBuffers: [outputBuffer],
        width: 512,
        height: 512
    )
    
    // Assert
    let result: [Float] = try metalUtil.extractData(from: outputBuffer, count: inputData.count)
    let expectedOutput = calculateExpectedOutput(from: inputData)
    
    try metalUtil.verifyArraysEqual(
        result: result,
        expected: expectedOutput,
        tolerance: 0.001
    )
}
```

## Using Test Utilities

### TestConfig

Use TestConfig to access standardized paths and configuration settings.

```swift
// Access test resources directory
let resourceURL = TestConfig.shared.testResourcesDir.appendingPathComponent("images")

// Check verbose logging setting
if TestConfig.shared.verboseLogging {
    print("Running test with parameters: \(parameters)")
}
```

### TestFixtureUtility

Use TestFixtureUtility to create and manage test environments.

```swift
// Create a fixture in setUp
func setUp() {
    super.setUp()
    testFixture = try createFixture()
    
    // Create test files
    try testFixture.createFile(
        at: "test.json",
        content: """
        {
            "key": "value"
        }
        """
    )
}

// Use the fixture in tests
func testFileProcessing() throws {
    let fileURL = testFixture.url(for: "test.json")
    let processor = JSONProcessor()
    let result = try processor.process(fileURL: fileURL)
    XCTAssertEqual(result["key"] as? String, "value")
}
```

### VisualTestUtility

Use VisualTestUtility for image comparison tests.

```swift
// Compare an image with a reference
func testImageFilter() throws {
    let inputImage = try loadTestImage(named: "test_image")
    let filteredImage = applyFilter(to: inputImage)
    
    try VisualTestUtility.compareImages(
        actual: filteredImage,
        expected: "filtered_reference",
        tolerance: 0.01,
        saveDiffOnFailure: true
    )
}

// Generate a test pattern
func testWithGeneratedPattern() throws {
    let testPattern = try VisualTestUtility.generateGradientImage(
        size: CGSize(width: 512, height: 512),
        startColor: .black,
        endColor: .white
    )
    
    let result = applyFilter(to: testPattern)
    
    // Verify properties of the result
    XCTAssertEqual(result.size, testPattern.size)
    // Additional assertions...
}
```

### PerformanceTestUtility

Use PerformanceTestUtility to measure and track performance.

```swift
// Measure execution time
func testProcessingTime() throws {
    let image = try loadTestImage(named: "high_res")
    
    try measureExecutionTime(
        name: "noise_reduction_4k",
        baselineValue: 100.0, // 100ms
        acceptableDeviation: 0.1 // 10%
    ) {
        _ = processor.applyNoiseReduction(to: image)
    }
}

// Measure memory usage
func testMemoryUsage() throws {
    let images = try loadTestImages(count: 10)
    
    try measureMemoryUsage(
        name: "hdr_merge_memory",
        baselineValue: 50.0, // 50MB
        acceptableDeviation: 0.2 // 20%
    ) {
        _ = merger.mergeImages(images)
    }
}
```

### ParameterizedTestUtility

Use ParameterizedTestUtility for data-driven tests.

```swift
// Test with multiple inputs
func testExposureAdjustment() throws {
    let testCases = [
        (input: 0.0, expected: 1.0),
        (input: 1.0, expected: 2.0),
        (input: -1.0, expected: 0.5)
    ]
    
    try runParameterizedTest(with: testCases) { input, expected, index in
        let result = calculateExposureValue(input)
        XCTAssertEqual(result, expected, accuracy: 0.001)
    }
}

// Load test data from JSON
func testWithJsonData() throws {
    let testData: [TestCase] = try loadTestData(fromJSON: "exposure_test_cases")
    
    try runParameterizedTest(with: testData) { testCase, index in
        let result = calculator.calculate(ev: testCase.input)
        XCTAssertEqual(result, testCase.expected, accuracy: 0.01)
    }
}
```

## Test Data Management

### Organization

- Store test data in the `TestResources` directory
- Organize by test type and feature
- Use descriptive file names

### Resource Types

- **Images**: Store in PNG format for lossless quality
- **JSON**: Use for structured test data and configurations
- **CSV**: Use for tabular test data
- **Raw**: Use for camera sensor data

### Generation

- Use `Scripts/generate-test-data.sh` to create test patterns and sample data
- Document the source and purpose of each test resource
- Version control test data alongside code

## CI Integration

### Test Selection

- Tag tests for selective execution:
  - `@slow` for time-consuming tests
  - `@requires_gpu` for tests needing GPU
  - `@visual` for visual comparison tests

### Troubleshooting CI Failures

- Check test logs in the TestResults directory
- Review visual diffs for failed visual tests
- Compare performance metrics against baselines
- Look for environment-specific issues

## Debugging Tests

### Enabling Verbose Output

```swift
// Enable verbose logging for a specific test
TestConfig.shared.verboseLogging = true
```

### Inspecting Visual Diffs

- Visual test failures generate diff images in the `TestResults/VisualTests/Diffs` directory
- Red pixels indicate areas where the actual image is darker
- Blue pixels indicate areas where the actual image is lighter
- The greater the color intensity, the larger the difference

### Analyzing Performance Issues

- Check the performance history in `TestResults/Performance/History`
- Look for gradual performance degradation over time
- Identify sudden changes that might indicate a regression

## Common Pitfalls

### Flaky Tests

**Causes:**
- Dependency on system state or timing
- Race conditions
- Resource contention

**Solutions:**
- Ensure test isolation
- Use deterministic input data
- Implement retry mechanisms for external dependencies

### Slow Tests

**Causes:**
- Processing large datasets
- Inefficient test setup
- Unnecessary operations

**Solutions:**
- Use smaller test data when possible
- Share setup across multiple tests where appropriate
- Mark slow tests and run them less frequently

### Brittle Visual Tests

**Causes:**
- Pixel-perfect comparison with zero tolerance
- Platform-specific rendering differences
- Dependency on external rendering engines

**Solutions:**
- Use appropriate tolerance values
- Focus comparisons on relevant regions
- Test image properties rather than exact pixels when appropriate

### Resource Leaks

**Causes:**
- Unclosed files or streams
- Unfreed memory or GPU resources
- Improperly terminated processes

**Solutions:**
- Use defer blocks or try-with-resources patterns
- Implement proper tearDown methods
- Use memory and resource monitoring in CI 