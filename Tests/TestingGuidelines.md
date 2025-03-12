# HDR+ Swift Testing Guidelines

This document provides guidelines and best practices for writing effective tests for the HDR+ Swift project. Following these guidelines will ensure consistent, maintainable, and valuable tests.

## Table of Contents

1. [Test Types and Organization](#test-types-and-organization)
2. [General Principles](#general-principles)
3. [Unit Testing Guidelines](#unit-testing-guidelines)
4. [Integration Testing Guidelines](#integration-testing-guidelines)
5. [Visual Testing Guidelines](#visual-testing-guidelines)
6. [Performance Testing Guidelines](#performance-testing-guidelines)
7. [Metal Testing Guidelines](#metal-testing-guidelines)
8. [Mocking Best Practices](#mocking-best-practices)
9. [Test Utilities](#test-utilities)
10. [Continuous Integration](#continuous-integration)

## Test Types and Organization

The HDR+ Swift project uses several types of tests, each with a specific purpose:

| Test Type | Purpose | Directory | Example |
|-----------|---------|-----------|---------|
| Unit Tests | Test individual components in isolation | `Tests/UnitTests/` | `AlignmentAlgorithmTests.swift` |
| Integration Tests | Test interactions between components | `Tests/IntegrationTests/` | `HDRPipelineIntegrationTests.swift` |
| Visual Tests | Verify visual output with image comparisons | `Tests/VisualTests/` | `ToneMappingVisualTests.swift` |
| Performance Tests | Verify execution time and memory usage | `Tests/PerformanceTests/` | `HDRMergePerformanceTests.swift` |
| Metal Tests | Test GPU-accelerated code | `Tests/MetalTests/` | `NoiseReductionShaderTests.swift` |

Organize test files to mirror the structure of the source code they test, but within their respective test type directory.

## General Principles

Follow these principles for all types of tests:

1. **Test Independence**: Each test should be independent and not rely on the state from other tests.
2. **Descriptive Names**: Use descriptive names that clearly indicate what is being tested.
3. **Arrange-Act-Assert**: Structure tests using the AAA pattern:
   ```swift
   func testExampleFunction() {
       // Arrange: Set up the test conditions
       let input = "example"
       
       // Act: Call the function being tested
       let result = exampleFunction(input)
       
       // Assert: Verify the expected outcome
       XCTAssertEqual(result, "EXAMPLE")
   }
   ```
4. **One Assertion Per Test**: Prefer one or a small number of related assertions per test.
5. **Clean Setup/Teardown**: Use `setUp()` and `tearDown()` methods to handle common setup and cleanup.
6. **Self-contained Tests**: Include all necessary context in the test method or setup.
7. **Test Edge Cases**: Include tests for boundary conditions and error cases.
8. **Consistent Formatting**: Follow the project's Swift style guide.

## Unit Testing Guidelines

Unit tests verify that individual components work correctly in isolation.

### Do's and Don'ts

✅ **Do:**
- Test one function or method per test
- Use mocks or stubs for dependencies
- Test edge cases and error conditions
- Keep tests simple and focused

❌ **Don't:**
- Access external resources (network, database, files)
- Write overly complex tests with too many assertions
- Create tests that depend on each other
- Test private implementation details unless necessary

### Example Unit Test

```swift
func testExposureCalculation() {
    // Arrange
    let calculator = ExposureCalculator()
    let iso = 100
    let shutterSpeed = 1.0/125.0
    let aperture = 2.8
    
    // Act
    let ev = calculator.calculateEV(
        iso: iso,
        shutterSpeed: shutterSpeed,
        aperture: aperture
    )
    
    // Assert
    XCTAssertEqual(ev, 11.0, accuracy: 0.01, "EV calculation should be accurate")
}
```

## Integration Testing Guidelines

Integration tests verify that components work together correctly.

### Do's and Don'ts

✅ **Do:**
- Test interactions between components
- Use real implementations when appropriate
- Focus on critical paths through the system
- Use test fixtures to set up a controlled environment

❌ **Don't:**
- Create excessively complex scenarios
- Rely on external systems unless absolutely necessary
- Write brittle tests that break with minor changes

### Example Integration Test

```swift
func testHDRPipelineProcessing() {
    // Arrange
    let fixture = createFixture()
    let images = loadTestImages(count: 3, from: fixture)
    let pipeline = createPipeline()
    
    // Act
    let result = pipeline.process(images: images)
    
    // Assert
    XCTAssertNotNil(result.finalImage, "Pipeline should produce a final image")
    XCTAssertEqual(result.metadata["processed"], true, "Metadata should indicate processing")
}
```

## Visual Testing Guidelines

Visual tests verify that image processing operations produce the expected visual output.

### Do's and Don'ts

✅ **Do:**
- Compare against reference images
- Use small, representative test images
- Set appropriate tolerance levels for comparisons
- Include test patterns that verify specific aspects

❌ **Don't:**
- Use excessively large test images
- Set tolerance too low (causing flaky tests) or too high (missing issues)
- Compare images with different dimensions or formats

### Example Visual Test

```swift
func testToneMapping() throws {
    // Arrange
    let input = try VisualTestUtility.generateHDRTestImage(width: 256, height: 256)
    let toneMapper = HDRToneMapper()
    
    // Act
    let result = toneMapper.process(input)
    
    // Assert
    try VisualTestUtility.compareImages(
        actual: result,
        expected: "tone_mapped_reference",
        tolerance: 0.02
    )
}
```

## Performance Testing Guidelines

Performance tests verify that operations meet performance requirements.

### Do's and Don'ts

✅ **Do:**
- Set realistic baseline values
- Allow for reasonable deviation (typically 10-20%)
- Use representative, real-world sized inputs
- Test on consistent hardware configurations

❌ **Don't:**
- Set overly strict performance requirements
- Measure operations with inconsistent timing
- Ignore memory usage
- Create tests that are too sensitive to hardware variations

### Example Performance Test

```swift
func testMergePerformance() throws {
    // Arrange
    let images = try loadTestImages(count: 8)
    let merger = HDRMerger()
    
    // Act & Assert
    try measureExecutionTime(
        name: "hdr_merge_8_images",
        baselineValue: 150.0,  // 150ms baseline
        acceptableDeviation: 0.2  // 20% deviation allowed
    ) {
        _ = merger.mergeImages(images)
    }
}
```

## Metal Testing Guidelines

Metal tests verify that GPU-accelerated code works correctly.

### Do's and Don'ts

✅ **Do:**
- Verify results against CPU implementations
- Test with various input sizes and configurations
- Handle devices where Metal is not available
- Use appropriate tolerances for floating-point comparisons

❌ **Don't:**
- Assume Metal is always available
- Compare CPU and GPU results with exact equality
- Ignore memory cleanup for GPU resources
- Create tests that require specific GPU hardware

### Example Metal Test

```swift
func testNoiseReductionShader() throws {
    // Arrange
    let metalUtil = try createMetalTestUtility()
    let pipeline = try metalUtil.createComputePipelineState(functionName: "denoise")
    
    let inputData: [Float] = createNoiseTestPattern(size: 64)
    let expectedData: [Float] = computeExpectedResult(inputData)
    
    let inputBuffer = try metalUtil.createBuffer(from: inputData)
    let outputBuffer = try metalUtil.createBuffer(count: inputData.count, type: Float.self)
    
    // Act
    try metalUtil.runComputeShader1D(
        pipelineState: pipeline,
        inputBuffers: [inputBuffer],
        outputBuffers: [outputBuffer],
        count: inputData.count
    )
    
    // Assert
    let result: [Float] = try metalUtil.extractData(from: outputBuffer, count: inputData.count)
    try metalUtil.verifyArraysEqual(result: result, expected: expectedData, tolerance: 0.001)
}
```

## Mocking Best Practices

Mocks allow testing components in isolation by simulating dependencies.

### Do's and Don'ts

✅ **Do:**
- Create focused mocks that only implement what's needed
- Use protocols to define interfaces for easy mocking
- Verify important interactions with mocks
- Keep mocks simple and maintainable

❌ **Don't:**
- Create overly complex mock implementations
- Mock everything by default
- Tightly couple tests to mock implementation details
- Use mocks when real implementations are simple and deterministic

### Example Mock

```swift
// Protocol defining the interface
protocol ImageAligner {
    func alignImages(_ images: [CGImage]) -> [CGImage]
}

// Mock implementation for testing
class MockImageAligner: ImageAligner {
    var alignImagesCalled = false
    var lastImagesInput: [CGImage]? = nil
    var alignedImagesResult: [CGImage] = []
    
    func alignImages(_ images: [CGImage]) -> [CGImage] {
        alignImagesCalled = true
        lastImagesInput = images
        return alignedImagesResult.isEmpty ? images : alignedImagesResult
    }
}

// Usage in a test
func testHDRPipelineWithMockAligner() {
    // Arrange
    let mockAligner = MockImageAligner()
    let expectedResult = createTestImage()
    mockAligner.alignedImagesResult = [expectedResult]
    
    let pipeline = HDRPipeline(aligner: mockAligner)
    let inputImages = [createTestImage(), createTestImage()]
    
    // Act
    let result = pipeline.process(images: inputImages)
    
    // Assert
    XCTAssertTrue(mockAligner.alignImagesCalled, "Aligner should be called")
    XCTAssertEqual(mockAligner.lastImagesInput?.count, 2, "Aligner should receive the input images")
}
```

## Test Utilities

The HDR+ Swift project provides several utilities to simplify testing:

### TestConfig

Centralized configuration for all tests.

```swift
// Access test resources directory
let resourceURL = TestConfig.shared.testResourcesDir.appendingPathComponent("images")

// Check verbose logging setting
if TestConfig.shared.verboseLogging {
    print("Debug info: \(debugInfo)")
}
```

### TestFixtureUtility

Manages test environments with temporary directories and files.

```swift
func testWithFixture() {
    // Create a test fixture
    let fixture = createFixture()
    
    // Create test files
    let configFile = fixture.createJSONFile(named: "config.json", object: ["key": "value"])
    
    // Use the fixture in the test
    let result = processConfigFile(configFile)
    
    // Fixture is automatically cleaned up when it goes out of scope
}
```

### VisualTestUtility

Provides tools for comparing images and verifying visual output.

```swift
func testImageProcessing() throws {
    // Generate or load a test image
    let input = try VisualTestUtility.generateTestImage(width: 512, height: 512)
    
    // Process the image
    let result = processImage(input)
    
    // Compare with a reference image
    try VisualTestUtility.compareImages(
        actual: result,
        expected: "reference_image",
        tolerance: 0.02
    )
}
```

### PerformanceTestUtility

Measures execution time and memory usage.

```swift
func testPerformanceCriticalOperation() throws {
    // Measure execution time
    try measureExecutionTime(
        name: "critical_operation",
        baselineValue: 100.0,  // 100ms
        acceptableDeviation: 0.15  // 15%
    ) {
        performCriticalOperation()
    }
    
    // Measure memory usage
    try measureMemoryUsage(
        name: "critical_operation_memory",
        baselineValue: 50.0  // 50MB
    ) {
        performCriticalOperation()
    }
}
```

### ParameterizedTestUtility

Enables data-driven testing with multiple input sets.

```swift
func testExposureAdjustment() throws {
    // Define test cases
    let testCases = [
        (input: 0.0, expected: 1.0),
        (input: 1.0, expected: 2.0),
        (input: -1.0, expected: 0.5)
    ]
    
    // Run test for each case
    try runParameterizedTest(with: testCases) { input, expected, _ in
        let result = calculateExposureValue(input)
        XCTAssertEqual(result, expected, accuracy: 0.001)
    }
}
```

### MetalTestUtility

Simplifies testing Metal shaders and compute pipelines.

```swift
func testMetalShader() throws {
    // Create the utility and pipeline
    let metalUtil = try createMetalTestUtility()
    let pipeline = try metalUtil.createComputePipelineState(functionName: "testShader")
    
    // Create input/output buffers
    let inputBuffer = try metalUtil.createBuffer(from: inputData)
    let outputBuffer = try metalUtil.createBuffer(count: outputSize, type: Float.self)
    
    // Run the shader
    try metalUtil.runComputeShader1D(
        pipelineState: pipeline,
        inputBuffers: [inputBuffer],
        outputBuffers: [outputBuffer],
        count: inputData.count
    )
    
    // Verify results
    let result: [Float] = try metalUtil.extractData(from: outputBuffer, count: outputSize)
    try metalUtil.verifyArraysEqual(result: result, expected: expectedOutput, tolerance: 0.001)
}
```

## Continuous Integration

The HDR+ Swift project uses GitHub Actions for continuous integration testing.

### Key CI Features

- **Automated Test Runs**: Tests run automatically on pull requests and pushes to main branches.
- **Test Matrix**: Tests run on multiple platforms and configurations.
- **Test Reports**: Results are reported as GitHub check status and detailed reports.
- **Flaky Test Detection**: Tests that pass inconsistently are flagged for review.
- **Performance Tracking**: Performance metrics are tracked over time to detect regressions.

### Pull Request Workflow

1. Create a pull request
2. CI automatically runs all relevant tests
3. Test results appear as checks on the PR
4. Fix any issues identified by tests
5. Once all tests pass, the PR can be merged

### Local Test Verification

Before submitting a PR, run tests locally:

```bash
# Run all tests
Scripts/run-tests.sh

# Run specific test types
Scripts/run-tests.sh --unit-only
Scripts/run-tests.sh --integration-only
Scripts/run-tests.sh --visual-only
Scripts/run-tests.sh --performance-only
Scripts/run-tests.sh --metal-only

# Filter tests by name
Scripts/run-tests.sh --regex "HDRMerge"
```

Following these guidelines will help maintain high-quality tests that effectively validate the HDR+ Swift project functionality, performance, and visual output. 