# HDR+ Swift Test Infrastructure

This directory contains the test infrastructure for the HDR+ Swift project, providing a comprehensive set of utilities and frameworks for testing various aspects of the application.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Test Utilities](#test-utilities)
- [Running Tests](#running-tests)
- [Adding New Tests](#adding-new-tests)
- [Visual Testing](#visual-testing)
- [Performance Testing](#performance-testing)
- [Metal Testing](#metal-testing)
- [Test Data Generation](#test-data-generation)
- [Test Resources](#test-resources)
- [Mocking](#mocking)
- [Test Reporting](#test-reporting)
- [Continuous Integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)

## Overview

The HDR+ Swift test infrastructure is designed to provide comprehensive testing capabilities for various aspects of the application, including:

- **Unit Testing**: Testing individual components in isolation
- **Integration Testing**: Testing interactions between components
- **Visual Testing**: Comparing processed images against reference images
- **Performance Testing**: Measuring execution time, memory usage, and other performance metrics
- **Metal Testing**: Testing GPU-accelerated code using Metal

The infrastructure includes a set of utility classes, test fixtures, and scripts for running tests and generating reports.

## Test Structure

The tests are organized into the following categories:

```
Tests/
  ├── UnitTests/          # Unit tests for individual components
  ├── IntegrationTests/   # Integration tests between components
  ├── PerformanceTests/   # Performance benchmarks and metrics
  ├── VisualTests/        # Visual regression tests
  ├── MetalTests/         # Tests for Metal shaders and GPU code
  ├── TestResources/      # Test data, reference images, and other resources
  ├── Scripts/            # Test-related scripts
  └── Utilities/          # Shared test utilities
```

## Test Utilities

The test infrastructure includes several utility classes to facilitate testing:

### `VisualTestUtility` 

Utility for visual regression testing, including:
- Comparing images with reference versions
- Generating visual diffs to highlight differences
- Managing reference images and test artifacts

```swift
// Example: Compare a processed image with a reference image
let matchesReference = VisualTestUtility.compareImage(
    processedImage,
    toReferenceNamed: "hdr_processed_image",
    tolerance: 0.02, // 2% tolerance
    in: self
)
```

### `PerformanceTestUtility`

Utility for measuring and tracking performance metrics, including:
- Execution time measurement
- Memory usage tracking
- Baseline comparison
- History tracking

```swift
// Example: Measure execution time
let timeMetric = PerformanceTestUtility.measureExecutionTime(
    name: "Demosaic Operation",
    baselineValue: 50.0, // 50ms baseline
    acceptableRange: 0.2  // 20% deviation allowed
) {
    // Code to measure
    imageProcessor.demosaic(rawImage)
}
```

### `MetalTestUtility`

Utility for testing Metal shaders and GPU code, including:
- Metal device and buffer management
- Shader loading and execution
- Test data generation and verification

```swift
// Example: Test a Metal shader
let inputData = [Float](repeating: 1.0, count: 4)
let outputBuffer = MetalTestUtility.createBuffer(size: 4 * MemoryLayout<Float>.size)

let pipelineState = try MetalTestUtility.loadShader(
    name: "test_shader",
    functionName: "multiply_by_two"
)

try MetalTestUtility.runShader(
    pipelineState: pipelineState,
    inputBuffers: ["input": inputBuffer],
    outputBuffers: ["output": outputBuffer],
    threadgroupSize: MTLSize(width: 1, height: 1, depth: 1),
    threadgroupCount: MTLSize(width: 1, height: 1, depth: 1)
)

let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: 4)
XCTAssertEqual(results, [2.0, 2.0, 2.0, 2.0])
```

### `TestFixtureUtility`

Utility for managing test fixtures and resources, including:
- Temporary file creation
- JSON and text file management
- Automatic cleanup

```swift
// Example: Create a test fixture
let fixture = createFixture()

// Create a mock configuration file
let configPath = fixture.createJSONFile(
    named: "camera_config.json",
    object: mockConfig
)

// Use the configuration in a test
let processor = ImageProcessor(configPath: configPath.path)
```

### `ParameterizedTestUtility`

Utility for running parameterized and data-driven tests, including:
- Parameter combination generation
- Named test cases
- Data-driven test support

```swift
// Example: Run a test with multiple parameters
runParameterized(
    name: "Exposure Calculation",
    parameters: [
        (aperture: 2.8, shutterSpeed: 1.0/125, iso: 100),
        (aperture: 4.0, shutterSpeed: 1.0/60, iso: 400),
        (aperture: 5.6, shutterSpeed: 1.0/30, iso: 800)
    ]
) { settings, testName in
    let (aperture, shutterSpeed, iso) = settings
    let ev = calculateEV(aperture: aperture, shutterSpeed: shutterSpeed, iso: iso)
    // Assertions here...
}
```

## Running Tests

Tests can be run using Xcode's built-in test navigator or using the provided `run-tests.sh` script:

```bash
# Run all tests
./Scripts/run-tests.sh

# Run specific test categories
./Scripts/run-tests.sh -u -p   # Run unit and performance tests

# Run tests with a filter
./Scripts/run-tests.sh -f "HDRProcessor"  # Run tests with "HDRProcessor" in the name

# Run tests with verbose output
./Scripts/run-tests.sh -v

# Run tests and generate a coverage report
./Scripts/run-tests.sh --coverage
```

The `run-tests.sh` script provides options for:
- Running specific test categories (unit, integration, visual, performance)
- Filtering tests by name
- Retrying flaky tests
- Generating reports and coverage information
- Verbose output

For full options, see:

```bash
./Scripts/run-tests.sh --help
```

## Adding New Tests

### Unit Tests

Unit tests should be added to the `UnitTests` directory, with one test case class per file. Each test case should:

- Extend `XCTestCase`
- Include appropriate `setUp` and `tearDown` methods
- Have descriptive test method names prefixed with `test`
- Include appropriate assertions using `XCTAssert` methods

```swift
class ImageProcessorTests: XCTestCase {
    var processor: ImageProcessor!
    
    override func setUp() {
        super.setUp()
        processor = ImageProcessor()
    }
    
    override func tearDown() {
        processor = nil
        super.tearDown()
    }
    
    func testDemosaicingWithMalvarAlgorithm() {
        // Test code...
        XCTAssertEqual(result.width, expected.width)
    }
}
```

### Integration Tests

Integration tests should be added to the `IntegrationTests` directory and should focus on testing the interaction between multiple components.

### Visual Tests

Visual tests should be added to the `VisualTests` directory and should use the `VisualTestUtility` class to compare processed images against reference images.

### Performance Tests

Performance tests should be added to the `PerformanceTests` directory and should use the `PerformanceTestUtility` class to measure performance metrics.

### Metal Tests

Metal tests should be added to the `MetalTests` directory and should use the `MetalTestUtility` class to test Metal shaders and GPU code.

## Visual Testing

Visual testing involves comparing processed images against reference images to ensure that the output matches expectations. The `VisualTestUtility` class provides methods for:

- Comparing images with reference versions
- Generating visual diffs to highlight differences
- Managing reference images and test artifacts

```swift
func testTonemapping() {
    // Process a test image
    let inputImage = loadTestImage("high_contrast_input")
    let processedImage = processor.tonemap(inputImage)
    
    // Compare with reference image
    let matchesReference = VisualTestUtility.compareImage(
        processedImage,
        toReferenceNamed: "tonemapped_high_contrast",
        tolerance: 0.02, // 2% tolerance
        in: self
    )
    
    XCTAssertTrue(matchesReference, "Processed image should match reference")
}
```

If the reference image doesn't exist, it will be created automatically. If the test fails, visual diff images will be saved to the `FailedTestArtifacts` directory, showing the differences between the expected and actual results.

## Performance Testing

Performance testing involves measuring the execution time, memory usage, and other performance metrics of the code. The `PerformanceTestUtility` class provides methods for:

- Measuring execution time
- Measuring memory usage
- Comparing against baselines
- Tracking performance history

```swift
func testDemosaicPerformance() {
    // Create test data
    let rawImage = createTestRawImage(width: 4000, height: 3000)
    
    // Measure execution time
    let timeMetric = PerformanceTestUtility.measureExecutionTime(
        name: "Demosaic 12MP Image",
        baselineValue: 50.0, // 50ms baseline
        acceptableRange: 0.2  // 20% deviation allowed
    ) {
        // Code to measure
        processor.demosaic(rawImage)
    }
    
    // Measure memory usage
    let memoryMetric = PerformanceTestUtility.measureMemoryUsage(
        name: "Demosaic Memory Usage",
        baselineValue: 100.0, // 100MB baseline
        acceptableRange: 0.2  // 20% deviation allowed
    ) {
        // Code to measure
        processor.demosaic(rawImage)
    }
    
    // Report results
    PerformanceTestUtility.reportResults(
        in: self,
        metrics: [timeMetric, memoryMetric]
    )
}
```

Performance metrics are saved to a history file, allowing tracking of performance changes over time.

## Metal Testing

Metal testing involves testing GPU-accelerated code using the Metal framework. The `MetalTestUtility` class provides methods for:

- Creating Metal buffers
- Loading and running shaders
- Extracting data from buffers
- Comparing arrays with tolerance

```swift
func testFrequencyMergeShader() {
    // Skip if Metal is not available
    MetalTestUtility.skipIfMetalNotAvailable(testCase: self)
    
    // Create test data
    let tile1 = createTestTile(width: 32, height: 32)
    let tile2 = createTestTile(width: 32, height: 32)
    
    // Create Metal buffers
    let inputBuffer1 = MetalTestUtility.createBuffer(from: tile1)
    let inputBuffer2 = MetalTestUtility.createBuffer(from: tile2)
    let outputBuffer = MetalTestUtility.createBuffer(size: tile1.count * MemoryLayout<Float>.size)
    
    // Load shader
    let pipelineState = try MetalTestUtility.loadShader(
        name: "frequency_merge",
        functionName: "wiener_merge"
    )
    
    // Run shader
    try MetalTestUtility.runShader(
        pipelineState: pipelineState,
        inputBuffers: ["tile1": inputBuffer1, "tile2": inputBuffer2],
        outputBuffers: ["output": outputBuffer],
        threadgroupSize: MTLSize(width: 8, height: 8, depth: 1),
        threadgroupCount: MTLSize(width: 4, height: 4, depth: 1)
    )
    
    // Verify results
    let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: tile1.count)
    // Assertions here...
}
```

## Test Data Generation

The test infrastructure includes a script for generating test data for visual and performance testing:

```bash
# Generate test patterns
./Scripts/generate-test-data.sh -p --size 1024x768

# Generate RAW test files with high noise
./Scripts/generate-test-data.sh -r --noise high

# Generate burst sequences with 10 frames each
./Scripts/generate-test-data.sh -b --burst-count 10

# Generate mock data for a specific camera model
./Scripts/generate-test-data.sh -m --camera highres
```

The script generates:
- Test patterns (gradients, checkerboards, color bars, etc.)
- Simulated RAW files with various exposure and noise levels
- Burst sequences with different scene types
- Mock data for camera models and pipeline configurations

## Test Resources

The test resources are organized in the `TestResources` directory, with the following structure:

```
TestResources/
  ├── ReferenceImages/    # Reference images for visual testing
  ├── TestInputs/         # Test input data
  │   ├── Patterns/       # Test patterns for visual testing
  │   ├── RAW/            # Simulated RAW files
  │   └── Bursts/         # Burst sequence data
  └── Mocks/              # Mock data for testing
```

## Mocking

The test infrastructure includes support for mocking various components of the system, including:
- Camera models and configurations
- Pipeline configurations
- File systems
- Network responses

The `TestFixtureUtility` class provides methods for creating and managing mock data and environments.

## Test Reporting

The test infrastructure includes support for generating reports on test results, including:
- Test summaries
- Visual test reports
- Performance metric history
- Code coverage reports

Reports are generated in the `TestResults` directory, with the following structure:

```
TestResults/
  ├── UnitTests.xcresult/     # Xcode test result bundle for unit tests
  ├── IntegrationTests.xcresult/ # Xcode test result bundle for integration tests
  ├── PerformanceTests.xcresult/ # Xcode test result bundle for performance tests
  ├── VisualTests.xcresult/  # Xcode test result bundle for visual tests
  ├── Performance/           # Performance test reports and history
  ├── VisualTests/           # Visual test artifacts and reports
  ├── Coverage/              # Code coverage reports
  └── test_report.html       # Combined test report
```

## Continuous Integration

The test infrastructure is designed to work with GitHub Actions for continuous integration. The CI pipeline includes:
- Running all tests on pull requests
- Tracking performance metrics
- Detecting flaky tests
- Generating reports

## Troubleshooting

### Visual Test Failures

If a visual test fails:
1. Check the `FailedTestArtifacts` directory for diff images
2. Compare the failed result with the reference image
3. Update the reference image if the changes are expected

### Performance Test Failures

If a performance test fails:
1. Check if the failure is consistent or spurious
2. Look for other processes that might be affecting performance
3. Update the baseline if the performance change is expected

### Metal Test Failures

If a Metal test fails:
1. Check if Metal is available on your device
2. Verify that the shader file exists and is correct
3. Check the input and output buffer sizes

### Flaky Tests

If a test fails intermittently:
1. Use the `--retry` option with `run-tests.sh`
2. Check for race conditions or time-dependent behavior
3. Increase timeouts or tolerance values if necessary 