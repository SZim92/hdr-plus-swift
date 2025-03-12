# HDR+ Swift Testing Guide

This document outlines the testing infrastructure for the HDR+ Swift project, including how to run tests, add new tests, and understand the CI test pipeline.

## Table of Contents

1. [Test Organization](#test-organization)
2. [Running Tests](#running-tests)
3. [Adding New Tests](#adding-new-tests)
4. [Test Categories](#test-categories)
5. [Metal Testing](#metal-testing)
6. [Visual Testing](#visual-testing)
7. [Performance Testing](#performance-testing)
8. [CI Test Pipeline](#ci-test-pipeline)
9. [Test Resources](#test-resources)
10. [Troubleshooting](#troubleshooting)

## Test Organization

The HDR+ Swift test suite is organized into the following categories:

```
Tests/
├── UnitTests/             # Tests for individual components in isolation
│   ├── CoreTests/         # Tests for core algorithms
│   ├── UtilsTests/        # Tests for utility functions
│   └── IOTests/           # Tests for input/output functions
├── IntegrationTests/      # Tests for how components work together
│   ├── AlignmentPipelineTests/
│   ├── MergePipelineTests/
│   └── EndToEndTests/
├── VisualTests/           # Tests for visual output quality
│   ├── ReferenceComparisons/
│   └── VisualRegressionTests/
├── PerformanceTests/      # Tests for performance metrics
│   ├── BenchmarkTests/
│   └── MemoryTests/
├── MetalTests/            # Tests for Metal GPU code
│   ├── ShaderTests/
│   └── MetalPipelineTests/
├── TestResources/         # Resources used by tests
│   ├── ReferenceImages/
│   └── TestInputs/
└── Utilities/             # Shared test utilities
    ├── MetalTestUtility.swift
    └── VisualTestUtility.swift
```

## Running Tests

### From Xcode

1. Open the HDR+ Swift project in Xcode
2. Use the Test Navigator (Cmd+6) to browse and run tests
3. To run all tests: Press Cmd+U
4. To run a specific test: Click the diamond icon next to the test

### From Command Line

```bash
# Run all tests
swift test

# Run tests in a specific file
swift test --filter "FrequencyMergeTests"

# Run a specific test
swift test --filter "FrequencyMergeTests/testFrequencyDomainWienerMerge"

# Generate coverage report
swift test --enable-code-coverage
```

### Setting Test Options

You can set test options using environment variables:

```bash
# Run tests with Metal validation enabled
METAL_VALIDATION=1 swift test

# Skip visual tests that require reference images
SKIP_VISUAL_TESTS=1 swift test

# Run performance tests with more iterations
PERF_TEST_ITERATIONS=20 swift test
```

## Adding New Tests

### Creating a Unit Test

1. Add a new Swift file to the appropriate test directory
2. Import XCTest and the module to test
3. Create a test class that inherits from XCTestCase
4. Add test methods that start with `test`

```swift
import XCTest
@testable import HDRPlusCore

class AlignmentTests: XCTestCase {
    
    func testTileAlignment() {
        // Arrange
        let tile1 = createTestTile(width: 32, height: 32)
        let tile2 = createTestTile(width: 32, height: 32)
        
        // Act
        let result = AlignmentModule.alignTiles(reference: tile1, alternate: tile2)
        
        // Assert
        XCTAssertEqual(result.offsetX, 0, accuracy: 0.1)
        XCTAssertEqual(result.offsetY, 0, accuracy: 0.1)
    }
}
```

### Test Naming Conventions

- Test classes: `[Feature]Tests.swift`
- Test methods: `test[Feature]_[Scenario]_[ExpectedResult]()`

## Test Categories

### Unit Tests

Unit tests verify that individual components work correctly in isolation. They should be:

- Fast: Execute in milliseconds
- Independent: Not dependent on other tests
- Repeatable: Produce the same result each time

### Integration Tests

Integration tests verify that components work together correctly. They test the interfaces between components and can include:

- Pipeline tests: Testing data flow through multiple components
- End-to-end tests: Testing complete workflows

### Visual Tests

Visual tests verify the visual quality of image processing operations by:

1. Processing test images
2. Comparing the results with reference images
3. Reporting differences beyond a threshold

### Performance Tests

Performance tests measure and track the performance of critical operations:

- Execution time
- Memory usage
- Metal shader performance

## Metal Testing

Metal tests verify GPU-accelerated code:

1. `MetalTestUtility` provides utilities for Metal testing
2. Tests automatically skip if Metal is not available
3. Helper methods simplify buffer creation and shader execution

Example Metal test:

```swift
func testMetalShader() throws {
    // Skip if Metal is not available
    MetalTestUtility.skipIfMetalNotAvailable(testCase: self)
    
    // Create test data and buffers
    let inputData = [Float](repeating: 1.0, count: 4)
    guard let inputBuffer = MetalTestUtility.createBuffer(from: inputData),
          let outputBuffer = MetalTestUtility.createBuffer(from: [Float](repeating: 0, count: 4)) else {
        XCTFail("Failed to create Metal buffers")
        return
    }
    
    // Load shader and run
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
    
    // Verify results
    let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: 4)
    XCTAssertEqual(results, [2.0, 2.0, 2.0, 2.0])
}
```

## Visual Testing

Visual testing compares processed images with reference images:

1. `VisualTestUtility` handles image comparison and difference visualization
2. Reference images are stored in `TestResources/ReferenceImages/`
3. Failed tests generate diff images showing differences

Example visual test:

```swift
func testTonemapping() {
    // Process a test image
    let inputImage = NSImage(named: "high_contrast_input")!
    let processor = TonemappingProcessor()
    let result = processor.process(image: inputImage)
    
    // Compare with reference image
    let match = VisualTestUtility.compareImage(
        result,
        toReferenceNamed: "tonemapped_high_contrast",
        tolerance: 0.01,
        in: self
    )
    
    XCTAssertTrue(match, "Processed image should match reference")
}
```

## Performance Testing

Performance tests measure and track execution metrics:

1. `PerformanceTestUtility` provides utilities for performance measurement
2. Results are stored for trend analysis
3. Tests can compare against baseline values

Example performance test:

```swift
func testAlignmentPerformance() {
    // Prepare test data
    let width = 1024, height = 768
    let tile1 = createTestTile(width: width, height: height)
    let tile2 = createTestTile(width: width, height: height)
    
    // Measure performance
    measurePerformance(name: "tile_alignment") {
        _ = AlignmentModule.alignTiles(reference: tile1, alternate: tile2)
    }
    
    // Report results
    reportPerformanceResults()
}
```

## CI Test Pipeline

The CI pipeline runs tests on multiple platforms and configurations:

1. **PR Validation**: Runs on pull requests
   - Basic unit tests and linting
   - Metal tests if supported

2. **Main Build**: Runs on the main branch
   - Full test suite including visual and performance tests
   - Multiple platforms (macOS 14, macOS 13)

3. **Nightly Build**: Runs every night
   - Extended tests including stress tests
   - Performance tracking and trend analysis

### CI Artifacts

The CI pipeline generates the following artifacts:

- Test reports (JUnit XML and JSON)
- Visual test diffs for failed tests
- Performance metrics history
- Metal diagnostics

## Test Resources

Test resources are stored in `Tests/TestResources/`:

- `ReferenceImages/`: Reference images for visual testing
- `TestInputs/`: Sample images for testing
- `Mocks/`: Mock objects and data

Large resources are not stored in Git. They can be downloaded using the script:

```bash
./Scripts/download_test_resources.sh
```

## Troubleshooting

### Common Issues

1. **Metal tests failing in CI**
   - Metal tests may fail in CI environments due to GPU limitations
   - Focus on build success rather than Metal test results in CI

2. **Visual tests failing after algorithm changes**
   - If the algorithm has legitimately changed, update reference images
   - Command: `swift run update_reference_images`

3. **Performance tests showing regressions**
   - Check if test platform has changed
   - Verify that the test is measuring the right thing
   - Update baseline if the change is expected

### Debugging Tips

1. **For unit test failures**
   - Use `XCTContext.runActivity` for nested diagnostics
   - Add breakpoints in test code

2. **For Metal test failures**
   - Enable Metal validation: `METAL_VALIDATION=1 swift test`
   - Check shader compilation errors

3. **For visual test failures**
   - Examine the diff images in `FailedTests/`
   - Check tolerance settings for comparison

4. **For performance test issues**
   - Run with more iterations for stability
   - Check for system load affecting results 