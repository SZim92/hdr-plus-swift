# HDR+ Swift Testing

This directory contains the test suite for the HDR+ Swift project. The testing infrastructure is designed to provide comprehensive validation of the HDR+ image processing pipeline through various test types and utilities.

## Directory Structure

```
Tests/
├── UnitTests/          # Tests for individual components
├── IntegrationTests/   # Tests for component interactions
├── VisualTests/        # Image comparison tests
├── PerformanceTests/   # Performance measurement tests
├── MetalTests/         # Tests for Metal shader code
├── TestResources/      # Test images and data files
├── TestConfig.swift    # Centralized test configuration
├── TestFixtureUtility.swift      # Test fixture management
├── VisualTestUtility.swift       # Visual testing utilities
├── PerformanceTestUtility.swift  # Performance testing utilities
├── ParameterizedTestUtility.swift # Data-driven test utilities
├── MetalTestUtility.swift        # Metal testing utilities
├── TestingGuidelines.md          # Guidelines for writing tests
├── TestInfrastructureEnhancements.md  # Overview of test infrastructure
└── README.md           # This file
```

## Test Types

### Unit Tests

Unit tests validate the behavior of individual components in isolation. These tests are fast, focused, and should cover all edge cases and error conditions.

Location: `UnitTests/`

Example:
```swift
func testExposureCalculation() {
    let calculator = ExposureCalculator()
    let result = calculator.calculateEV(iso: 100, shutterSpeed: 1.0/125.0)
    XCTAssertEqual(result, 13.0, accuracy: 0.01)
}
```

### Integration Tests

Integration tests validate the interactions between multiple components. These tests ensure that components work together correctly.

Location: `IntegrationTests/`

Example:
```swift
func testCaptureAndProcessPipeline() {
    let camera = MockCamera()
    let processor = HDRProcessor()
    let pipeline = HDRPipeline(camera: camera, processor: processor)
    
    let result = pipeline.captureAndProcess(frameCount: 3)
    XCTAssertNotNil(result.finalImage)
}
```

### Visual Tests

Visual tests compare processed images against reference images to verify that image processing algorithms produce the expected visual results.

Location: `VisualTests/`

Example:
```swift
func testToneMapping() throws {
    let input = try loadTestImage("hdr_input")
    let processor = HDRToneMapper()
    
    let result = processor.process(input)
    
    try VisualTestUtility.compareImages(
        actual: result,
        expected: "tone_mapped_reference",
        tolerance: 0.02
    )
}
```

### Performance Tests

Performance tests measure the execution time and memory usage of operations to ensure they meet performance requirements.

Location: `PerformanceTests/`

Example:
```swift
func testMergePerformance() throws {
    let images = try loadTestImages(count: 8)
    
    try measureExecutionTime(
        name: "hdr_merge_8_images",
        baselineValue: 150.0  // 150ms baseline
    ) {
        _ = try merger.mergeImages(images)
    }
}
```

### Metal Tests

Metal tests validate the correctness of GPU-accelerated code, ensuring shaders and compute kernels produce the expected results.

Location: `MetalTests/`

Example:
```swift
func testNoiseReductionShader() throws {
    let metalUtil = try createMetalTestUtility()
    let pipelineState = try metalUtil.createComputePipelineState(functionName: "denoise_shader")
    
    // Run shader and verify results
    // ...
}
```

## Test Utilities

### TestConfig

`TestConfig` is a singleton that provides centralized configuration for all tests, including paths, settings, and environment variables.

Usage:
```swift
// Access test resources directory
let resourceURL = TestConfig.shared.testResourcesDir.appendingPathComponent("images")

// Check verbose logging setting
if TestConfig.shared.verboseLogging {
    print("Debug info: \(debugInfo)")
}
```

### TestFixtureUtility

`TestFixtureUtility` manages test environments, creating temporary directories and files that are automatically cleaned up after tests run.

Usage:
```swift
// In setUp method
testFixture = try createFixture()

// Create test files
try testFixture.createFile(at: "config.json", content: "{\"key\": \"value\"}")

// Use files in tests
let fileURL = testFixture.url(for: "config.json")
```

### VisualTestUtility

`VisualTestUtility` provides tools for comparing images and verifying visual output.

Usage:
```swift
// Compare an image with a reference
try VisualTestUtility.compareImages(
    actual: processedImage,
    expected: "reference_image",
    tolerance: 0.02,
    saveDiffOnFailure: true
)

// Generate a test pattern
let testPattern = try VisualTestUtility.generateCheckerboardPattern(
    size: CGSize(width: 512, height: 512),
    checkSize: 64,
    colors: [.black, .white]
)
```

### PerformanceTestUtility

`PerformanceTestUtility` measures and tracks performance metrics over time.

Usage:
```swift
// Measure execution time
try measureExecutionTime(
    name: "operation_name",
    baselineValue: 100.0,  // 100ms
    acceptableDeviation: 0.1  // 10%
) {
    // Code to measure
    performOperation()
}

// Measure memory usage
try measureMemoryUsage(
    name: "operation_memory",
    baselineValue: 50.0  // 50MB
) {
    // Code to measure
    performOperation()
}
```

### ParameterizedTestUtility

`ParameterizedTestUtility` enables data-driven testing with multiple input sets.

Usage:
```swift
// Test with multiple inputs
let testCases = [
    (input: 0.0, expected: 1.0),
    (input: 1.0, expected: 2.0),
    (input: -1.0, expected: 0.5)
]

try runParameterizedTest(with: testCases) { input, expected, index in
    let result = calculator.calculate(input)
    XCTAssertEqual(result, expected, accuracy: 0.001)
}

// Load test data from JSON
let testData: [TestCase] = try loadTestData(fromJSON: "test_cases")
```

### MetalTestUtility

`MetalTestUtility` simplifies testing Metal shaders and compute kernels.

Usage:
```swift
// Create utility and pipeline
let metalUtil = try createMetalTestUtility()
let pipeline = try metalUtil.createComputePipelineState(functionName: "shader_name")

// Create buffers
let inputBuffer = try metalUtil.createBuffer(from: inputData)
let outputBuffer = try metalUtil.createBuffer(count: outputSize, type: Float.self)

// Run shader
try metalUtil.runComputeShader1D(
    pipelineState: pipeline,
    inputBuffers: [inputBuffer],
    outputBuffers: [outputBuffer],
    count: inputData.count
)

// Verify results
let result: [Float] = try metalUtil.extractData(from: outputBuffer, count: outputSize)
try metalUtil.verifyArraysEqual(result: result, expected: expectedOutput, tolerance: 0.001)
```

## Running Tests

### Using Xcode

1. Open the project in Xcode
2. Select the test scheme
3. Use Cmd+U to run all tests, or select specific tests to run

### Using Command Line

Use the test runner scripts in the `Scripts` directory:

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

# Generate reports
Scripts/run-tests.sh --report-format html
```

### Using CI

The project includes GitHub Actions workflows for running tests in CI:

- Push to main or develop branches triggers a full test suite
- Pull requests trigger relevant tests based on changed files
- Manual workflow runs can be triggered with specific test filters

## Test Resources

Test resources are stored in the `TestResources` directory, organized by category:

- `TestResources/Images/` - Test images for visual tests
- `TestResources/References/` - Reference images for comparison
- `TestResources/TestData/` - JSON and CSV data for parameterized tests
- `TestResources/Mock/` - Mock data for simulating inputs

## Contributing Tests

When adding new tests to the project:

1. Follow the [Testing Guidelines](TestingGuidelines.md)
2. Place tests in the appropriate directory based on type
3. Use the provided test utilities for consistent testing
4. Include necessary test resources
5. Ensure tests run reliably and are not flaky

## Additional Documentation

- [Testing Guidelines](TestingGuidelines.md) - Best practices for writing effective tests
- [Test Infrastructure Enhancements](TestInfrastructureEnhancements.md) - Overview of the test infrastructure
- [Metal Tests README](MetalTests/README.md) - Specific guidance for Metal tests 