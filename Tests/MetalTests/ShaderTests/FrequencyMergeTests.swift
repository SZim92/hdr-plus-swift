import XCTest
import Metal

class FrequencyMergeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Skip the entire test suite if Metal is not available
        MetalTestUtility.skipIfMetalNotAvailable(testCase: self)
    }
    
    func testFrequencyDomainWienerMerge() throws {
        // Create test input data
        let width = 32
        let height = 32
        let inputTile1 = createTestTile(width: width, height: height, intensity: 0.5)
        let inputTile2 = createTestTile(width: width, height: height, intensity: 0.7)
        let noise = 0.05 // Noise level
        
        // Create Metal buffers
        guard let inputBuffer1 = MetalTestUtility.createBuffer(from: inputTile1),
              let inputBuffer2 = MetalTestUtility.createBuffer(from: inputTile2),
              let outputBuffer = MetalTestUtility.createBuffer(from: [Float](repeating: 0, count: width * height * 4)) else {
            XCTFail("Failed to create Metal buffers")
            return
        }
        
        // Create parameters buffer
        let params = [Float(width), Float(height), Float(noise)]
        guard let paramsBuffer = MetalTestUtility.createBuffer(from: params) else {
            XCTFail("Failed to create parameters buffer")
            return
        }
        
        // Load the shader
        let pipelineState = try XCTUnwrap(
            try MetalTestUtility.loadShader(name: "test_frequency_merge", functionName: "wiener_merge")
        )
        
        // Set up thread dimensions
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        // Run the shader
        try MetalTestUtility.runShader(
            pipelineState: pipelineState,
            inputBuffers: [
                "input1": inputBuffer1,
                "input2": inputBuffer2,
                "params": paramsBuffer
            ],
            outputBuffers: ["output": outputBuffer],
            threadgroupSize: threadgroupSize,
            threadgroupCount: threadgroupCount
        )
        
        // Extract results
        let outputData: [Float] = MetalTestUtility.extractData(from: outputBuffer, count: width * height * 4)
        
        // Verify results
        verifyMergeResults(outputData: outputData, width: width, height: height)
    }
    
    func testFrequencyDomainPerformance() throws {
        // Create test input data
        let width = 256
        let height = 256
        let inputTile1 = createTestTile(width: width, height: height, intensity: 0.5)
        let inputTile2 = createTestTile(width: width, height: height, intensity: 0.7)
        let noise = 0.05 // Noise level
        
        // Create Metal buffers
        guard let inputBuffer1 = MetalTestUtility.createBuffer(from: inputTile1),
              let inputBuffer2 = MetalTestUtility.createBuffer(from: inputTile2),
              let outputBuffer = MetalTestUtility.createBuffer(from: [Float](repeating: 0, count: width * height * 4)) else {
            XCTFail("Failed to create Metal buffers")
            return
        }
        
        // Create parameters buffer
        let params = [Float(width), Float(height), Float(noise)]
        guard let paramsBuffer = MetalTestUtility.createBuffer(from: params) else {
            XCTFail("Failed to create parameters buffer")
            return
        }
        
        // Load the shader
        let pipelineState = try XCTUnwrap(
            try MetalTestUtility.loadShader(name: "test_frequency_merge", functionName: "wiener_merge")
        )
        
        // Set up thread dimensions
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        // Measure performance
        measure {
            try? MetalTestUtility.runShader(
                pipelineState: pipelineState,
                inputBuffers: [
                    "input1": inputBuffer1,
                    "input2": inputBuffer2,
                    "params": paramsBuffer
                ],
                outputBuffers: ["output": outputBuffer],
                threadgroupSize: threadgroupSize,
                threadgroupCount: threadgroupCount
            )
        }
    }
    
    // MARK: - Helper methods
    
    /// Create a test tile with random data
    private func createTestTile(width: Int, height: Int, intensity: Float) -> [Float] {
        var tile = [Float](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                
                // Create test pattern with some variation
                let normX = Float(x) / Float(width - 1)
                let normY = Float(y) / Float(height - 1)
                
                // Generate a simple pattern with a gradient
                tile[i] = normX * intensity // R
                tile[i+1] = normY * intensity // G
                tile[i+2] = (normX + normY) * 0.5 * intensity // B
                tile[i+3] = 1.0 // A
                
                // Add some noise
                tile[i] += Float.random(in: -0.1...0.1) * intensity
                tile[i+1] += Float.random(in: -0.1...0.1) * intensity
                tile[i+2] += Float.random(in: -0.1...0.1) * intensity
            }
        }
        
        return tile
    }
    
    /// Verify the results of the merge operation
    private func verifyMergeResults(outputData: [Float], width: Int, height: Int) {
        // Check a few basic properties of the result
        
        // 1. Output should not be empty (all zeros)
        var sumOutput: Float = 0
        for i in stride(from: 0, to: outputData.count, by: 4) {
            sumOutput += outputData[i] + outputData[i+1] + outputData[i+2]
        }
        XCTAssertGreaterThan(sumOutput, 0, "Output should not be all zeros")
        
        // 2. Output values should be in valid range [0,1]
        var allInRange = true
        for i in stride(from: 0, to: outputData.count, by: 4) {
            if outputData[i] < 0 || outputData[i] > 1 ||
               outputData[i+1] < 0 || outputData[i+1] > 1 ||
               outputData[i+2] < 0 || outputData[i+2] > 1 {
                allInRange = false
                break
            }
        }
        XCTAssertTrue(allInRange, "All output values should be in range [0,1]")
        
        // 3. Alpha channel should be preserved
        var alphaCorrect = true
        for i in stride(from: 3, to: outputData.count, by: 4) {
            if abs(outputData[i] - 1.0) > 0.001 {
                alphaCorrect = false
                break
            }
        }
        XCTAssertTrue(alphaCorrect, "Alpha channel should be preserved")
    }
}

// MARK: - Metal Shader for Testing

// This would normally be a separate .metal file, 
// but for the demo we're creating a mock test
// that doesn't depend on the actual implementation

/*
// test_frequency_merge.metal
#include <metal_stdlib>
using namespace metal;

kernel void wiener_merge(
    device float4* input1 [[buffer(0)]],
    device float4* input2 [[buffer(1)]],
    device float* params [[buffer(2)]],
    device float4* output [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]])
{
    int width = int(params[0]);
    int height = int(params[1]);
    float noise = params[2];
    
    // Check bounds
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    // Get index
    uint index = gid.y * width + gid.x;
    
    // In a real implementation, this would do a frequency domain merge with Wiener filtering
    // Here we just do a basic weighted average for testing
    float4 color1 = input1[index];
    float4 color2 = input2[index];
    
    // Simple weighted average based on signal-to-noise ratio
    float signal1 = length(color1.rgb);
    float signal2 = length(color2.rgb);
    
    float weight1 = signal1 / (signal1 + noise);
    float weight2 = signal2 / (signal2 + noise);
    
    float totalWeight = weight1 + weight2;
    if (totalWeight > 0) {
        weight1 /= totalWeight;
        weight2 /= totalWeight;
    } else {
        weight1 = weight2 = 0.5;
    }
    
    // Blend colors
    float4 result;
    result.rgb = color1.rgb * weight1 + color2.rgb * weight2;
    result.a = 1.0; // Preserve alpha
    
    output[index] = result;
}
*/ 