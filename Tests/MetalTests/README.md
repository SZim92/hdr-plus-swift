# Metal Testing in HDR+ Swift

This directory contains tests for Metal GPU code used in the HDR+ Swift project. The Metal tests verify that our GPU-accelerated implementations work correctly.

## Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Test Structure](#test-structure)
- [Writing Metal Tests](#writing-metal-tests)
- [Running Metal Tests](#running-metal-tests)
- [Debugging Metal Tests](#debugging-metal-tests)
- [Common Issues](#common-issues)

## Overview

Metal tests verify the correctness of GPU-accelerated code in the HDR+ Swift project. These tests are essential for ensuring that:

1. Metal shaders produce correct results
2. GPU implementation matches CPU reference implementation
3. Edge cases are handled properly
4. Performance meets expectations

We use the `MetalTestUtility` class to help create and run Metal tests efficiently.

## Requirements

To run Metal tests, you need:

- macOS 11.0 or later
- Xcode 13.0 or later
- A macOS or iOS device with Metal support

Note that Metal tests may not run correctly in the iOS Simulator, and some tests may be skipped automatically on devices that don't support required Metal features.

## Test Structure

The Metal tests are organized into the following categories:

```
MetalTests/
  ├── ShaderTests/             # Tests for individual Metal shaders
  ├── PipelineTests/           # Tests for Metal compute pipelines
  ├── AlignmentMetalTests/     # Tests for GPU-accelerated alignment
  ├── MergeMetalTests/         # Tests for GPU-accelerated merging
  ├── ToneMapMetalTests/       # Tests for GPU-accelerated tone mapping
  └── PerformanceMetalTests/   # Performance tests for Metal code
```

## Writing Metal Tests

### Basic Structure

Here's a template for a typical Metal test:

```swift
import XCTest
@testable import HDRPlusCore

class MyMetalShaderTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Skip test if Metal is not available
        MetalTestUtility.skipIfMetalNotAvailable(testCase: self)
    }
    
    func testMyShader() {
        // Create test data
        let inputData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let expectedOutput: [Float] = [2.0, 4.0, 6.0, 8.0]
        
        // Create Metal buffers
        let inputBuffer = MetalTestUtility.createBuffer(from: inputData)
        let outputBuffer = MetalTestUtility.createBuffer(size: inputData.count * MemoryLayout<Float>.size)
        
        do {
            // Load the shader
            let shaderFunction = "multiplyByTwo"
            let pipelineState = try MetalTestUtility.loadShader(
                name: "MyShader",
                functionName: shaderFunction
            )
            
            // Set up and run the shader
            try MetalTestUtility.runShader(
                pipelineState: pipelineState,
                inputBuffers: ["input": inputBuffer],
                outputBuffers: ["output": outputBuffer],
                threadgroupSize: MTLSize(width: 1, height: 1, depth: 1),
                threadgroupCount: MTLSize(width: inputData.count, height: 1, depth: 1)
            )
            
            // Get results and verify
            let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: inputData.count)
            
            // Compare with expected output
            XCTAssertEqual(results, expectedOutput, accuracy: 0.0001)
        } catch {
            XCTFail("Metal test failed with error: \(error)")
        }
    }
}
```

### Using the MetalTestUtility

The `MetalTestUtility` class provides several helpful methods for Metal testing:

#### Checking Metal Availability

```swift
// Skip test if Metal is not available
MetalTestUtility.skipIfMetalNotAvailable(testCase: self)

// Skip test if specific Metal feature is not available
MetalTestUtility.skipIfFeatureNotAvailable(.arrayOfTextures, testCase: self)
```

#### Creating Metal Buffers

```swift
// Create a buffer from data
let floatBuffer = MetalTestUtility.createBuffer(from: [Float])
let intBuffer = MetalTestUtility.createBuffer(from: [Int32])

// Create an empty buffer of specific size
let outputBuffer = MetalTestUtility.createBuffer(size: 1024)
```

#### Loading Metal Shaders

```swift
// Load a compute shader
let pipelineState = try MetalTestUtility.loadShader(
    name: "MyShader",     // Metal file name (without .metal extension)
    functionName: "myFunction"  // Function name within the shader
)

// Load a shader with custom compile options
let options = MTLCompileOptions()
options.fastMathEnabled = true
let pipelineState = try MetalTestUtility.loadShader(
    name: "MyShader",
    functionName: "myFunction",
    compileOptions: options
)
```

#### Running Shaders

```swift
// Run a compute shader
try MetalTestUtility.runShader(
    pipelineState: pipelineState,
    inputBuffers: [
        "inputA": bufferA, 
        "inputB": bufferB
    ],
    outputBuffers: [
        "output": outputBuffer
    ],
    threadgroupSize: MTLSize(width: 16, height: 16, depth: 1),
    threadgroupCount: MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
)

// Run with additional uniform values
try MetalTestUtility.runShader(
    pipelineState: pipelineState,
    inputBuffers: ["input": inputBuffer],
    outputBuffers: ["output": outputBuffer],
    uniformValues: [
        ("scale", Float(2.0)),
        ("offset", Float(1.0))
    ],
    threadgroupSize: MTLSize(width: 16, height: 1, depth: 1),
    threadgroupCount: MTLSize(width: (count + 15) / 16, height: 1, depth: 1)
)
```

#### Extracting Data from Buffers

```swift
// Extract data from a buffer
let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: 100)
let intResults: [Int32] = MetalTestUtility.extractData(from: outputBuffer, count: 100)
```

#### Comparing Arrays with Tolerance

```swift
// Compare two arrays with a tolerance for floating-point values
let matches = MetalTestUtility.compareArrays(
    results,
    expectedOutput,
    tolerance: 0.0001
)
XCTAssertTrue(matches, "Output doesn't match expected values")
```

### Testing Different Metal Shader Types

#### 1D Data Processing

```swift
func testOneDimensionalData() {
    let inputData: [Float] = Array(0..<1024).map { Float($0) }
    let expectedOutput: [Float] = inputData.map { $0 * 2.0 }
    
    // Create buffers
    let inputBuffer = MetalTestUtility.createBuffer(from: inputData)
    let outputBuffer = MetalTestUtility.createBuffer(size: inputData.count * MemoryLayout<Float>.size)
    
    do {
        // Load and run shader
        let pipelineState = try MetalTestUtility.loadShader(
            name: "ScalarOperations",
            functionName: "multiplyByTwo"
        )
        
        try MetalTestUtility.runShader(
            pipelineState: pipelineState,
            inputBuffers: ["input": inputBuffer],
            outputBuffers: ["output": outputBuffer],
            threadgroupSize: MTLSize(width: 256, height: 1, depth: 1),
            threadgroupCount: MTLSize(width: (inputData.count + 255) / 256, height: 1, depth: 1)
        )
        
        // Verify results
        let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: inputData.count)
        XCTAssertTrue(MetalTestUtility.compareArrays(results, expectedOutput, tolerance: 0.0001))
    } catch {
        XCTFail("Test failed with error: \(error)")
    }
}
```

#### 2D Image Processing

```swift
func testTwoDimensionalData() {
    let width = 64
    let height = 64
    let size = width * height
    
    // Create test image data
    let inputData: [Float] = Array(0..<size).map { Float($0) / Float(size) }
    let expectedOutput: [Float] = inputData.map { sqrt($0) }
    
    // Create buffers
    let inputBuffer = MetalTestUtility.createBuffer(from: inputData)
    let outputBuffer = MetalTestUtility.createBuffer(size: size * MemoryLayout<Float>.size)
    
    do {
        // Load and run shader
        let pipelineState = try MetalTestUtility.loadShader(
            name: "ImageProcessing",
            functionName: "applySqrt"
        )
        
        try MetalTestUtility.runShader(
            pipelineState: pipelineState,
            inputBuffers: ["input": inputBuffer],
            outputBuffers: ["output": outputBuffer],
            uniformValues: [
                ("width", UInt32(width)),
                ("height", UInt32(height))
            ],
            threadgroupSize: MTLSize(width: 16, height: 16, depth: 1),
            threadgroupCount: MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
        )
        
        // Verify results
        let results: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: size)
        XCTAssertTrue(MetalTestUtility.compareArrays(results, expectedOutput, tolerance: 0.0001))
    } catch {
        XCTFail("Test failed with error: \(error)")
    }
}
```

## Running Metal Tests

You can run Metal tests using:

1. Xcode's Test Navigator
2. The command line:
   ```bash
   xcodebuild test -scheme HDRPlusCore -only-testing MetalTests
   ```
3. The run-tests.sh script:
   ```bash
   ./Scripts/run-tests.sh -m  # Run only Metal tests
   ```

## Debugging Metal Tests

To debug Metal tests:

1. Use the `debugMode: true` parameter when running shaders:
   ```swift
   try MetalTestUtility.runShader(
       pipelineState: pipelineState,
       inputBuffers: ["input": inputBuffer],
       outputBuffers: ["output": outputBuffer],
       threadgroupSize: threadgroupSize,
       threadgroupCount: threadgroupCount,
       debugMode: true  // Enable debugging
   )
   ```

2. Use Metal Frame Debugger in Xcode:
   - Set a breakpoint in your test
   - Run the test in debug mode
   - When the breakpoint hits, choose Debug > Capture GPU Frame
   - Inspect shader execution and buffer contents

3. Print buffer contents:
   ```swift
   // Print buffer contents for debugging
   MetalTestUtility.printBuffer(buffer: outputBuffer, count: 10, label: "Output buffer")
   ```

## Common Issues

### Test Timeouts

Metal tests may time out if the GPU is very busy or if a shader has an infinite loop. Try:

1. Increasing the timeout in XCTest:
   ```swift
   func testLongRunningShader() throws {
       // Set longer timeout for this test
       let expectation = self.expectation(description: "Shader completion")
       
       // Your test code here
       
       // Wait for up to 30 seconds
       wait(for: [expectation], timeout: 30.0)
   }
   ```

2. Checking for infinite loops in your shaders

### Precision Issues

Metal and CPU calculations may have slightly different precision. To handle this:

1. Use appropriate tolerance in comparisons:
   ```swift
   XCTAssertTrue(
       MetalTestUtility.compareArrays(results, expectedOutput, tolerance: 0.001),
       "Results differ by more than 0.1%"
   )
   ```

2. Be especially careful with operations sensitive to precision (e.g., division, trigonometric functions)

### Device-Specific Issues

Some tests may only run on specific devices:

1. Use feature detection to skip tests when needed:
   ```swift
   MetalTestUtility.skipIfFeatureNotAvailable(.arrayOfTextures, testCase: self)
   ```

2. Test on multiple GPU types when possible 