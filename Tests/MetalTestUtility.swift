import Foundation
import XCTest
import Metal

/// Utility for testing Metal code, providing methods for setting up Metal contexts,
/// running shaders, and verifying results.
public final class MetalTestUtility {
    
    /// Errors that can occur during Metal testing
    public enum MetalTestError: Error, LocalizedError {
        /// Metal is not available on this device
        case metalNotAvailable
        
        /// Failed to create a Metal device
        case deviceCreationFailed
        
        /// Failed to create a command queue
        case commandQueueCreationFailed
        
        /// Failed to create a compute pipeline state
        case pipelineCreationFailed(String)
        
        /// Failed to create a buffer
        case bufferCreationFailed(String)
        
        /// Failed to create a compute command encoder
        case commandEncoderCreationFailed
        
        /// Failed to complete a command buffer
        case commandBufferExecutionFailed(String)
        
        /// Failed to extract data from a buffer
        case dataExtractionFailed(String)
        
        /// Verification failed - results don't match expectations
        case verificationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .metalNotAvailable:
                return "Metal is not available on this device"
            case .deviceCreationFailed:
                return "Failed to create a Metal device"
            case .commandQueueCreationFailed:
                return "Failed to create a command queue"
            case .pipelineCreationFailed(let reason):
                return "Failed to create a compute pipeline state: \(reason)"
            case .bufferCreationFailed(let reason):
                return "Failed to create a buffer: \(reason)"
            case .commandEncoderCreationFailed:
                return "Failed to create a compute command encoder"
            case .commandBufferExecutionFailed(let reason):
                return "Failed to complete a command buffer: \(reason)"
            case .dataExtractionFailed(let reason):
                return "Failed to extract data from a buffer: \(reason)"
            case .verificationFailed(let reason):
                return "Verification failed - results don't match expectations: \(reason)"
            }
        }
    }
    
    /// The Metal device to use for testing
    public let device: MTLDevice
    
    /// The default Metal library containing shader functions
    public let defaultLibrary: MTLLibrary
    
    /// The command queue for executing Metal commands
    public let commandQueue: MTLCommandQueue
    
    /// Initializes a new MetalTestUtility.
    ///
    /// - Throws: MetalTestError if Metal is not available or required components can't be created.
    public init() throws {
        // Check if Metal is available
        guard Self.isMetalAvailable() else {
            throw MetalTestError.metalNotAvailable
        }
        
        // Create a Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalTestError.deviceCreationFailed
        }
        self.device = device
        
        // Create a default library
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            throw MetalTestError.pipelineCreationFailed("Could not create default library")
        }
        self.defaultLibrary = defaultLibrary
        
        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalTestError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
    }
    
    /// Creates a Metal buffer with the specified contents.
    ///
    /// - Parameters:
    ///   - array: The array to load into the buffer.
    ///   - options: The resource options for the buffer.
    /// - Returns: A Metal buffer.
    /// - Throws: MetalTestError if the buffer can't be created.
    public func createBuffer<T>(
        from array: [T],
        options: MTLResourceOptions = []
    ) throws -> MTLBuffer {
        let byteLength = array.count * MemoryLayout<T>.stride
        
        guard let buffer = device.makeBuffer(
            bytes: array,
            length: byteLength,
            options: options
        ) else {
            throw MetalTestError.bufferCreationFailed("Failed to create buffer of size \(byteLength) bytes")
        }
        
        return buffer
    }
    
    /// Creates an empty Metal buffer with the specified size.
    ///
    /// - Parameters:
    ///   - count: The number of elements to allocate.
    ///   - options: The resource options for the buffer.
    /// - Returns: A Metal buffer.
    /// - Throws: MetalTestError if the buffer can't be created.
    public func createBuffer<T>(
        count: Int,
        type: T.Type,
        options: MTLResourceOptions = []
    ) throws -> MTLBuffer {
        let byteLength = count * MemoryLayout<T>.stride
        
        guard let buffer = device.makeBuffer(
            length: byteLength,
            options: options
        ) else {
            throw MetalTestError.bufferCreationFailed("Failed to create buffer of size \(byteLength) bytes")
        }
        
        return buffer
    }
    
    /// Extracts data from a Metal buffer.
    ///
    /// - Parameters:
    ///   - buffer: The Metal buffer to extract data from.
    ///   - count: The number of elements to extract.
    /// - Returns: An array of the extracted data.
    /// - Throws: MetalTestError if the data can't be extracted.
    public func extractData<T>(
        from buffer: MTLBuffer,
        count: Int
    ) throws -> [T] {
        let expectedByteLength = count * MemoryLayout<T>.stride
        
        guard buffer.length >= expectedByteLength else {
            throw MetalTestError.dataExtractionFailed(
                "Buffer too small: expected at least \(expectedByteLength) bytes, but buffer is \(buffer.length) bytes"
            )
        }
        
        guard let contents = buffer.contents().bindMemory(
            to: T.self,
            capacity: count
        ) as? UnsafePointer<T> else {
            throw MetalTestError.dataExtractionFailed("Failed to bind memory")
        }
        
        return Array(UnsafeBufferPointer(start: contents, count: count))
    }
    
    /// Creates a compute pipeline state for the specified function.
    ///
    /// - Parameter functionName: The name of the shader function.
    /// - Returns: A compute pipeline state.
    /// - Throws: MetalTestError if the pipeline can't be created.
    public func createComputePipelineState(
        functionName: String
    ) throws -> MTLComputePipelineState {
        guard let function = defaultLibrary.makeFunction(name: functionName) else {
            throw MetalTestError.pipelineCreationFailed("Could not find function '\(functionName)'")
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw MetalTestError.pipelineCreationFailed("Failed to create pipeline for function '\(functionName)': \(error)")
        }
    }
    
    /// Runs a 1D compute shader with the specified parameters.
    ///
    /// - Parameters:
    ///   - pipelineState: The compute pipeline state to use.
    ///   - inputBuffers: The input buffers to bind.
    ///   - outputBuffers: The output buffers to bind.
    ///   - count: The number of iterations to run.
    /// - Throws: MetalTestError if the shader can't be executed.
    public func runComputeShader1D(
        pipelineState: MTLComputePipelineState,
        inputBuffers: [MTLBuffer],
        outputBuffers: [MTLBuffer],
        count: Int
    ) throws {
        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalTestError.commandBufferExecutionFailed("Could not create command buffer")
        }
        
        // Create a compute command encoder
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalTestError.commandEncoderCreationFailed
        }
        
        // Set the compute pipeline state
        encoder.setComputePipelineState(pipelineState)
        
        // Set input buffers
        for (index, buffer) in inputBuffers.enumerated() {
            encoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Set output buffers
        for (index, buffer) in outputBuffers.enumerated() {
            encoder.setBuffer(buffer, offset: 0, index: index + inputBuffers.count)
        }
        
        // Calculate the thread configuration
        let threadsPerThreadgroup = min(pipelineState.maxTotalThreadsPerThreadgroup, 1024)
        let threadgroupsPerGrid = (count + threadsPerThreadgroup - 1) / threadsPerThreadgroup
        
        // Dispatch the threads
        encoder.dispatchThreadgroups(
            MTLSize(width: threadgroupsPerGrid, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1)
        )
        
        // End encoding
        encoder.endEncoding()
        
        // Execute the command buffer
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Check for errors
        if let error = commandBuffer.error {
            throw MetalTestError.commandBufferExecutionFailed("Command buffer failed with error: \(error.localizedDescription)")
        }
    }
    
    /// Runs a 2D compute shader with the specified parameters.
    ///
    /// - Parameters:
    ///   - pipelineState: The compute pipeline state to use.
    ///   - inputBuffers: The input buffers to bind.
    ///   - outputBuffers: The output buffers to bind.
    ///   - width: The width of the 2D grid.
    ///   - height: The height of the 2D grid.
    /// - Throws: MetalTestError if the shader can't be executed.
    public func runComputeShader2D(
        pipelineState: MTLComputePipelineState,
        inputBuffers: [MTLBuffer],
        outputBuffers: [MTLBuffer],
        width: Int,
        height: Int
    ) throws {
        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalTestError.commandBufferExecutionFailed("Could not create command buffer")
        }
        
        // Create a compute command encoder
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalTestError.commandEncoderCreationFailed
        }
        
        // Set the compute pipeline state
        encoder.setComputePipelineState(pipelineState)
        
        // Set input buffers
        for (index, buffer) in inputBuffers.enumerated() {
            encoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Set output buffers
        for (index, buffer) in outputBuffers.enumerated() {
            encoder.setBuffer(buffer, offset: 0, index: index + inputBuffers.count)
        }
        
        // Calculate the thread configuration
        let threadsPerThreadgroup = MTLSize(
            width: min(16, pipelineState.threadExecutionWidth),
            height: min(16, pipelineState.maxTotalThreadsPerThreadgroup / 16),
            depth: 1
        )
        
        let threadgroupsPerGrid = MTLSize(
            width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        
        // Dispatch the threads
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        // End encoding
        encoder.endEncoding()
        
        // Execute the command buffer
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Check for errors
        if let error = commandBuffer.error {
            throw MetalTestError.commandBufferExecutionFailed("Command buffer failed with error: \(error.localizedDescription)")
        }
    }
    
    /// Verifies that the result array matches the expected array.
    ///
    /// - Parameters:
    ///   - result: The result array.
    ///   - expected: The expected array.
    ///   - tolerance: The tolerance for floating-point comparisons, or nil for exact equality.
    /// - Throws: MetalTestError if the arrays don't match.
    public func verifyArraysEqual<T: Equatable>(
        result: [T],
        expected: [T],
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if result.count != expected.count {
            throw MetalTestError.verificationFailed(
                "Arrays have different sizes: result has \(result.count) elements, expected has \(expected.count) elements"
            )
        }
        
        for (index, (resultValue, expectedValue)) in zip(result, expected).enumerated() {
            if resultValue != expectedValue {
                throw MetalTestError.verificationFailed(
                    "Arrays differ at index \(index): result = \(resultValue), expected = \(expectedValue)"
                )
            }
        }
    }
    
    /// Verifies that the result array matches the expected array within the specified tolerance.
    ///
    /// - Parameters:
    ///   - result: The result array.
    ///   - expected: The expected array.
    ///   - tolerance: The tolerance for comparisons.
    /// - Throws: MetalTestError if the arrays don't match within the tolerance.
    public func verifyArraysEqual<T: FloatingPoint>(
        result: [T],
        expected: [T],
        tolerance: T,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if result.count != expected.count {
            throw MetalTestError.verificationFailed(
                "Arrays have different sizes: result has \(result.count) elements, expected has \(expected.count) elements"
            )
        }
        
        for (index, (resultValue, expectedValue)) in zip(result, expected).enumerated() {
            if abs(resultValue - expectedValue) > tolerance {
                throw MetalTestError.verificationFailed(
                    "Arrays differ at index \(index): result = \(resultValue), expected = \(expectedValue), difference = \(abs(resultValue - expectedValue)), tolerance = \(tolerance)"
                )
            }
        }
    }
    
    /// Checks if Metal is available on the current device.
    ///
    /// - Returns: Whether Metal is available.
    public static func isMetalAvailable() -> Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Skips the test if Metal is not available on the current device.
    ///
    /// - Throws: An error if the test should be skipped.
    public func skipIfMetalUnavailable() throws {
        if !MetalTestUtility.isMetalAvailable() {
            throw XCTSkip("Metal is not available on this device")
        }
    }
    
    /// Creates a MetalTestUtility, skipping the test if Metal is not available.
    ///
    /// - Returns: A MetalTestUtility.
    /// - Throws: An error if Metal is not available or the utility can't be created.
    public func createMetalTestUtility() throws -> MetalTestUtility {
        try skipIfMetalUnavailable()
        return try MetalTestUtility()
    }
} 