# HDR+ Swift Testing Framework

This directory contains a comprehensive testing framework for the HDR+ Swift project, designed to make testing of image processing algorithms easier, more reliable, and more insightful.

## Test Utilities

The testing framework includes several utilities to help with different aspects of testing:

### TestConfig

`TestConfig` provides centralized configuration for all tests in the project:

- Environment variable support for customizing test behavior
- Consistent directory structure for test resources, fixtures, and results
- Helper methods for managing test resources and directories

```swift
// Example: Get a reference image URL
let referenceURL = TestConfig.shared.referenceImageURL(for: "tonemap_test", in: type(of: self))

// Example: Create required directories
TestConfig.shared.createDirectories()

// Example: Log verbose output when enabled
TestConfig.shared.logVerbose("Processing test image...")
```

### TestFixtureUtility

`TestFixtureUtility` provides easy management of test fixtures and mocks:

- Automatic cleanup of test fixtures when tests complete
- Helper methods for creating files, directories, and test data
- Built-in helpers for common mock objects (camera config, burst frames, etc.)

```swift
// Example: Create a test fixture
let fixture = createFixture()

// Example: Create a text file in the fixture
let configFile = fixture.createTextFile(named: "settings.json", contents: "{...}")

// Example: Create a mock camera configuration
let cameraConfigURL = TestFixtureUtility.createMockCameraConfig(in: fixture)
```

### VisualTestUtility

`VisualTestUtility` helps with image comparison and visual regression testing:

- Compare generated images with reference images
- Save reference images when they don't exist
- Generate visual diffs to highlight differences between images
- Helper methods for creating test images

```swift
// Example: Compare an image to a reference
let matches = VisualTestUtility.compareImage(
    processedImage,
    toReferenceNamed: "hdr_tonemap",
    tolerance: 0.01,
    in: self
)

// Example: Create a test image
let testImage = VisualTestUtility.createGradientImage(
    width: 512,
    height: 512,
    startColor: (red: 0.0, green: 0.0, blue: 0.0),
    endColor: (red: 1.0, green: 1.0, blue: 1.0)
)
```

### PerformanceTestUtility

`PerformanceTestUtility` helps with performance testing and tracking:

- Measure execution time and memory usage of operations
- Track performance metrics over time
- Compare performance against baselines with acceptable deviation

```swift
// Example: Measure execution time
let executionTime = measureExecutionTime(name: "hdr_merge") {
    processor.processImage(input)
}

// Example: Measure memory usage
let memoryUsage = measureMemoryUsage(name: "hdr_alignment") {
    aligner.alignFrames(burstFrames)
}
```

### ParameterizedTestUtility

`ParameterizedTestUtility` enables data-driven testing:

- Run tests with multiple input parameters
- Load test data from JSON and CSV files
- Create parameter grids for testing combinations of parameters

```swift
// Example: Run tests with multiple parameters
runParameterized(name: "exposure_test", parameters: [0.5, 1.0, 2.0]) { value, testName in
    let result = processor.adjustExposure(input, value: value)
    XCTAssertNotNil(result, "\(testName): Result should not be nil")
}

// Example: Run tests with parameter combinations
runParameterizedGrid(
    name: "tonemap_test",
    parameters1: [(0.5, "lowExposure"), (1.0, "normalExposure"), (2.0, "highExposure")],
    parameters2: [("filmic", "filmicTonemap"), ("aces", "acesTonemap")]
) { exposure, tonemapType, testName in
    let result = processor.tonemap(input, exposure: exposure, type: tonemapType)
    XCTAssertNotNil(result, "\(testName): Result should not be nil")
}
```

### MetalTestUtility

`MetalTestUtility` helps with testing Metal GPU code:

- Run compute shaders with test data
- Compare results with expected values
- Skip tests automatically when Metal is not available

```swift
// Example: Create a Metal test utility
let metalUtil = try createMetalTestUtility()

// Example: Run a 1D compute shader
try metalUtil.runComputeShader1D(
    functionName: "add_arrays",
    inputBuffers: [(0, inputBuffer1), (1, inputBuffer2)],
    outputBuffers: [(2, outputBuffer)],
    count: 1024
)

// Example: Verify results
let results = metalUtil.getBufferData(from: outputBuffer, type: Float.self, count: 1024)
try metalUtil.compareArrays(actual: results, expected: expectedResults, tolerance: 0.001)
```

## Test Categories

The test suite is organized into the following categories:

### Unit Tests

Located in `Tests/UnitTests/`, these tests focus on testing individual components in isolation.

### Integration Tests

Located in `Tests/IntegrationTests/`, these tests verify the interaction between multiple components.

### Visual Tests

Located in `Tests/VisualTests/`, these tests compare generated images with reference images to detect visual regressions.

### Performance Tests

Located in `Tests/PerformanceTests/`, these tests measure the performance of operations and track changes over time.

### Metal Tests

Located in `Tests/MetalTests/`, these tests verify the correctness of Metal compute shaders.

## Running Tests

The project includes several ways to run tests:

### Running in Xcode

1. Open the project in Xcode
2. Select the test scheme
3. Press Cmd+U or select Product > Test

### Running from Command Line

```bash
# Run all tests
swift test

# Run a specific test target
swift test --filter VisualTests

# Run a specific test case
swift test --filter VisualTests/HDRToneMapVisualTests

# Run a specific test method
swift test --filter VisualTests/HDRToneMapVisualTests/testBasicToneMapping
```

### Using the Test Runner Script

The project includes a test runner script at `Scripts/run-tests.sh`:

```bash
# Run all tests
./Scripts/run-tests.sh

# Run with options
./Scripts/run-tests.sh --unit --visual --performance --verbose

# Run with retry for flaky tests
./Scripts/run-tests.sh --retry 3

# Generate a test report
./Scripts/run-tests.sh --report
```

## Writing Tests

### Unit Tests

```swift
import XCTest
@testable import HDRPlus

class MyComponentTests: XCTestCase {
    func testSomeFunction() {
        // Arrange
        let component = MyComponent()
        
        // Act
        let result = component.someFunction()
        
        // Assert
        XCTAssertEqual(result, expectedResult)
    }
}
```

### Visual Tests

```swift
import XCTest
@testable import HDRPlus

class MyVisualTests: XCTestCase {
    func testImageProcessing() {
        // Arrange
        let processor = ImageProcessor()
        let input = createTestImage()
        
        // Act
        let result = processor.process(input)
        
        // Assert using visual comparison
        let matches = VisualTestUtility.compareImage(
            result,
            toReferenceNamed: "processed_image",
            tolerance: 0.01,
            in: self
        )
        
        XCTAssertTrue(matches)
    }
}
```

### Performance Tests

```swift
import XCTest
@testable import HDRPlus

class MyPerformanceTests: XCTestCase {
    func testProcessingPerformance() {
        // Arrange
        let processor = ImageProcessor()
        let input = createTestImage()
        
        // Act and assert with performance measurement
        measureExecutionTime(name: "image_processing") {
            _ = processor.process(input)
        }
    }
}
```

### Metal Tests

```swift
import XCTest
@testable import HDRPlus

class MyMetalTests: XCTestCase {
    func testComputeShader() throws {
        // Skip test if Metal is not available
        skipIfMetalUnavailable()
        
        // Arrange
        let metalUtil = try createMetalTestUtility()
        let input = [Float](repeating: 1.0, count: 1024)
        
        // Create buffers
        let inputBuffer = try metalUtil.createBuffer(from: input)
        let outputBuffer = try metalUtil.createBuffer(length: MemoryLayout<Float>.stride * 1024)
        
        // Act
        try metalUtil.runComputeShader1D(
            functionName: "square_values",
            inputBuffers: [(0, inputBuffer)],
            outputBuffers: [(1, outputBuffer)],
            count: 1024
        )
        
        // Assert
        let results = metalUtil.getBufferData(from: outputBuffer, type: Float.self, count: 1024)
        let expected = input.map { $0 * $0 }
        try metalUtil.compareArrays(actual: results, expected: expected, tolerance: 0.001)
    }
}
```

## Best Practices

1. **Use Test Fixtures**: Create and clean up test data with `TestFixtureUtility` to ensure tests are isolated.
2. **Parameterize Tests**: Use `ParameterizedTestUtility` to test multiple scenarios without duplicating code.
3. **Track Performance**: Use `PerformanceTestUtility` to catch performance regressions early.
4. **Visual Regression Testing**: Create reference images for important visual outputs and compare against them.
5. **Skip Tests When Appropriate**: Use `skipIfMetalUnavailable()` to skip tests that can't run on the current device.
6. **Use Named Test Parameters**: Give descriptive names to test parameters to make test failures easier to understand.

## Troubleshooting

### Visual Tests Failing

1. Check if reference images exist in the reference directory.
2. Look at the failed test image and diff to see what's different.
3. If the changes are expected, update the reference images.

### Performance Tests Failing

1. Check if the baseline exists and if it's reasonable.
2. Look at the performance history to see if there's a trend.
3. Update the baseline if the performance change is expected.

### Metal Tests Failing

1. Check if Metal is available on the device.
2. Verify shader function names match those in the Metal library.
3. Check buffer sizes and types.

### Flaky Tests

1. Use the test retry feature to identify flaky tests.
2. Review the test for race conditions or external dependencies.
3. Consider using more stable test fixtures or mocks. 