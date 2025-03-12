import Foundation
import XCTest
import Metal

/// Utility for testing Metal shaders and compute pipelines.
/// Provides methods for setting up Metal contexts, running shaders, and verifying results.
public final class MetalTestUtility {
    
    // MARK: - Error Types
    
    /// Error types that can occur during Metal testing
    public enum MetalTestError: Error, LocalizedError {
        /// Metal is not available on this device
        case metalNotAvailable
        
        /// Failed to create a Metal device
        case deviceCreationFailed
        
        /// Failed to create a command queue
        case commandQueueCreationFailed
        
        /// Failed to create a Metal compute pipeline state
        case computePipelineCreationFailed(String)
        
        /// Failed to create a buffer
        case bufferCreationFailed(String)
        
        /// Failed to find the specified function in the library
        case functionNotFound(String)
        
        /// General shader execution error
        case shaderExecutionFailed(String)
        
        /// Threading group size error
        case threadingError(String)
        
        /// Buffer size mismatch
        case bufferSizeMismatch(String)
        
        /// Result verification failed
        case verificationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .metalNotAvailable:
                return "Metal is not available on this device"
            case .deviceCreationFailed:
                return "Failed to create a Metal device"
            case .commandQueueCreationFailed:
                return "Failed to create a Metal command queue"
            case .computePipelineCreationFailed(let message):
                return "Failed to create compute pipeline: \(message)"
            case .bufferCreationFailed(let message):
                return "Failed to create buffer: \(message)"
            case .functionNotFound(let name):
                return "Function '\(name)' not found in Metal library"
            case .shaderExecutionFailed(let message):
                return "Shader execution failed: \(message)"
            case .threadingError(let message):
                return "Threading error: \(message)"
            case .bufferSizeMismatch(let message):
                return "Buffer size mismatch: \(message)"
            case .verificationFailed(let message):
                return "Verification failed: \(message)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The Metal device to use for testing
    public let device: MTLDevice
    
    /// The default Metal library
    public let defaultLibrary: MTLLibrary
    
    /// The command queue for submitting Metal commands
    public let commandQueue: MTLCommandQueue
    
    // MARK: - Initialization
    
    /// Initialize a new Metal test utility
    /// - Throws: An error if Metal is not available or initialization fails
    public init() throws {
        // Check if Metal is available
        guard MetalTestUtility.isMetalAvailable() else {
            throw MetalTestError.metalNotAvailable
        }
        
        // Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalTestError.deviceCreationFailed
        }
        self.device = device
        
        // Get the default library
        guard let defaultLibrary = try? device.makeDefaultLibrary() else {
            throw MetalTestError.functionNotFound("Default Metal library not found")
        }
        self.defaultLibrary = defaultLibrary
        
        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalTestError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
    }
    
    // MARK: - Buffer Methods
    
    /// Create a Metal buffer from an array of values
    /// - Parameters:
    ///   - array: The array of values to copy into the buffer
    ///   - options: Options for buffer creation (default: .storageModeShared)
    /// - Returns: A Metal buffer containing the data
    /// - Throws: An error if buffer creation fails
    public func createBuffer<T>(from array: [T], options: MTLResourceOptions = .storageModeShared) throws -> MTLBuffer {
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
    
    /// Create an empty Metal buffer with a specific element count and type
    /// - Parameters:
    ///   - count: The number of elements the buffer should hold
    ///   - type: The type of elements in the buffer
    ///   - options: Options for buffer creation (default: .storageModeShared)
    /// - Returns: An empty Metal buffer of the specified size
    /// - Throws: An error if buffer creation fails
    public func createBuffer<T>(count: Int, type: T.Type, options: MTLResourceOptions = .storageModeShared) throws -> MTLBuffer {
        let byteLength = count * MemoryLayout<T>.stride
        
        guard let buffer = device.makeBuffer(length: byteLength, options: options) else {
            throw MetalTestError.bufferCreationFailed("Failed to create buffer of size \(byteLength) bytes")
        }
        
        return buffer
    }
    
    /// Extract data from a Metal buffer into an array
    /// - Parameters:
    ///   - buffer: The Metal buffer to extract data from
    ///   - count: The number of elements to extract
    /// - Returns: An array containing the extracted data
    /// - Throws: An error if data extraction fails
    public func extractData<T>(from buffer: MTLBuffer, count: Int) throws -> [T] {
        let expectedByteLength = count * MemoryLayout<T>.stride
        guard buffer.length >= expectedByteLength else {
            throw MetalTestError.bufferSizeMismatch(
                "Buffer size (\(buffer.length) bytes) is smaller than required size (\(expectedByteLength) bytes)"
            )
        }
        
        let data = Data(bytesNoCopy: buffer.contents(), count: expectedByteLength, deallocator: .none)
        var result = [T](repeating: (0 as! T), count: count)
        
        _ = result.withUnsafeMutableBytes { resultPtr in
            data.copyBytes(to: resultPtr)
        }
        
        return result
    }
    
    // MARK: - Pipeline Methods
    
    /// Create a compute pipeline state for the given function
    /// - Parameters:
    ///   - functionName: The name of the Metal function
    ///   - library: The Metal library to use (defaults to the default library)
    /// - Returns: A compute pipeline state for the function
    /// - Throws: An error if pipeline creation fails
    public func createComputePipelineState(
        functionName: String,
        library: MTLLibrary? = nil
    ) throws -> MTLComputePipelineState {
        let library = library ?? defaultLibrary
        
        guard let function = library.makeFunction(name: functionName) else {
            throw MetalTestError.functionNotFound(functionName)
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw MetalTestError.computePipelineCreationFailed("Failed to create pipeline for function '\(functionName)': \(error)")
        }
    }
    
    // MARK: - Shader Execution
    
    /// Run a 1D compute shader
    /// - Parameters:
    ///   - pipelineState: The compute pipeline state to use
    ///   - inputBuffers: Array of input buffers
    ///   - outputBuffers: Array of output buffers
    ///   - count: The number of elements to process
    ///   - threadsPerGroup: The number of threads per thread group (default: 32)
    /// - Throws: An error if shader execution fails
    public func runComputeShader1D(
        pipelineState: MTLComputePipelineState,
        inputBuffers: [MTLBuffer],
        outputBuffers: [MTLBuffer],
        count: Int,
        threadsPerGroup: Int = 32
    ) throws {
        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalTestError.shaderExecutionFailed("Failed to create command buffer")
        }
        
        // Create a compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalTestError.shaderExecutionFailed("Failed to create compute encoder")
        }
        
        // Set the compute pipeline state
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Set input buffers
        for (index, buffer) in inputBuffers.enumerated() {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Set output buffers
        for (index, buffer) in outputBuffers.enumerated() {
            computeEncoder.setBuffer(buffer, offset: 0, index: index + inputBuffers.count)
        }
        
        // Calculate the grid size
        let threadsPerGrid = MTLSize(width: count, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: min(threadsPerGroup, pipelineState.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        
        // Dispatch the threads
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        // End encoding
        computeEncoder.endEncoding()
        
        // Commit the command buffer and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Check for errors
        if let error = commandBuffer.error {
            throw MetalTestError.shaderExecutionFailed("Command buffer execution failed: \(error)")
        }
    }
    
    /// Run a 2D compute shader
    /// - Parameters:
    ///   - pipelineState: The compute pipeline state to use
    ///   - inputBuffers: Array of input buffers
    ///   - outputBuffers: Array of output buffers
    ///   - width: The width of the 2D grid
    ///   - height: The height of the 2D grid
    ///   - threadsPerGroup: The number of threads per thread group (default: (8, 8))
    /// - Throws: An error if shader execution fails
    public func runComputeShader2D(
        pipelineState: MTLComputePipelineState,
        inputBuffers: [MTLBuffer],
        outputBuffers: [MTLBuffer],
        width: Int,
        height: Int,
        threadsPerGroup: (width: Int, height: Int) = (8, 8)
    ) throws {
        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalTestError.shaderExecutionFailed("Failed to create command buffer")
        }
        
        // Create a compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalTestError.shaderExecutionFailed("Failed to create compute encoder")
        }
        
        // Set the compute pipeline state
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Set input buffers
        for (index, buffer) in inputBuffers.enumerated() {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Set output buffers
        for (index, buffer) in outputBuffers.enumerated() {
            computeEncoder.setBuffer(buffer, offset: 0, index: index + inputBuffers.count)
        }
        
        // Calculate the grid size
        let threadsPerGrid = MTLSize(width: width, height: height, depth: 1)
        let maxThreadsPerThreadgroup = pipelineState.maxTotalThreadsPerThreadgroup
        let threadsPerThreadgroup = MTLSize(
            width: min(threadsPerGroup.width, maxThreadsPerThreadgroup),
            height: min(threadsPerGroup.height, maxThreadsPerThreadgroup / threadsPerGroup.width),
            depth: 1
        )
        
        // Dispatch the threads
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        // End encoding
        computeEncoder.endEncoding()
        
        // Commit the command buffer and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Check for errors
        if let error = commandBuffer.error {
            throw MetalTestError.shaderExecutionFailed("Command buffer execution failed: \(error)")
        }
    }
    
    // MARK: - Verification Methods
    
    /// Verify that two arrays are equal
    /// - Parameters:
    ///   - result: The result array
    ///   - expected: The expected array
    /// - Throws: An error if the arrays are not equal
    public func verifyArraysEqual<T: Equatable>(result: [T], expected: [T]) throws {
        guard result.count == expected.count else {
            throw MetalTestError.verificationFailed("Array counts don't match: \(result.count) vs \(expected.count)")
        }
        
        for i in 0..<result.count {
            if result[i] != expected[i] {
                throw MetalTestError.verificationFailed("Array elements at index \(i) don't match: \(result[i]) vs \(expected[i])")
            }
        }
    }
    
    /// Verify that two arrays are approximately equal within a tolerance
    /// - Parameters:
    ///   - result: The result array
    ///   - expected: The expected array
    ///   - tolerance: The maximum allowed difference between elements
    /// - Throws: An error if the arrays are not approximately equal
    public func verifyArraysEqual<T: FloatingPoint>(result: [T], expected: [T], tolerance: T) throws {
        guard result.count == expected.count else {
            throw MetalTestError.verificationFailed("Array counts don't match: \(result.count) vs \(expected.count)")
        }
        
        for i in 0..<result.count {
            if abs(result[i] - expected[i]) > tolerance {
                throw MetalTestError.verificationFailed(
                    "Array elements at index \(i) differ by more than tolerance \(tolerance): \(result[i]) vs \(expected[i])"
                )
            }
        }
    }
    
    // MARK: - Static Methods
    
    /// Check if Metal is available on this device
    /// - Returns: Whether Metal is available
    public static func isMetalAvailable() -> Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Skip the test if Metal is not available
    /// - Throws: An XCTestError with skip message if Metal is not available
    public func skipIfMetalUnavailable() throws {
        if !MetalTestUtility.isMetalAvailable() {
            throw XCTSkip("This test requires Metal, which is not available on this device")
        }
    }
    
    /// Create a Metal test utility, or skip the test if Metal is not available
    /// - Returns: A new MetalTestUtility
    /// - Throws: An XCTestError with skip message if Metal is not available
    public func createMetalTestUtility() throws -> MetalTestUtility {
        do {
            return try MetalTestUtility()
        } catch MetalTestUtility.MetalTestError.metalNotAvailable {
            throw XCTSkip("This test requires Metal, which is not available on this device")
        } catch {
            throw error
        }
    }
} 