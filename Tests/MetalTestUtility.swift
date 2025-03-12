import Foundation
import XCTest
import Metal

/// Utility for testing Metal shaders and compute pipelines.
/// This provides methods for setting up Metal contexts, running shaders,
/// and verifying results against expected values.
public class MetalTestUtility {
    
    // MARK: - Types
    
    /// Error types that can occur during Metal testing
    public enum MetalTestError: Error {
        case deviceNotAvailable
        case libraryCreationFailed(error: Error?)
        case functionNotFound(name: String)
        case pipelineCreationFailed(error: Error?)
        case bufferCreationFailed
        case commandQueueCreationFailed
        case commandBufferCreationFailed
        case commandEncoderCreationFailed
        case executionFailed(error: Error?)
        case resultMismatch(description: String)
    }
    
    // MARK: - Properties
    
    /// The Metal device to use for testing
    public let device: MTLDevice
    
    /// The default library containing Metal shaders
    public let defaultLibrary: MTLLibrary
    
    /// The command queue for executing Metal commands
    public let commandQueue: MTLCommandQueue
    
    // MARK: - Initialization
    
    /// Creates a new Metal test utility
    /// - Parameter libraryBundle: The bundle containing the Metal library
    public init(libraryBundle: Bundle = Bundle.main) throws {
        // Check if Metal is available
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalTestError.deviceNotAvailable
        }
        self.device = device
        
        // Create the default library
        do {
            self.defaultLibrary = try device.makeDefaultLibrary(bundle: libraryBundle)
        } catch {
            throw MetalTestError.libraryCreationFailed(error: error)
        }
        
        // Create the command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalTestError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
    }
    
    /// Creates a Metal buffer from an array of values
    /// - Parameters:
    ///   - array: The array to create a buffer from
    ///   - options: The resource options for the buffer
    /// - Returns: The created Metal buffer
    /// - Throws: MetalTestError.bufferCreationFailed if the buffer creation fails
    public func createBuffer<T>(
        from array: [T],
        options: MTLResourceOptions = []
    ) throws -> MTLBuffer {
        let bufferSize = MemoryLayout<T>.stride * array.count
        
        guard let buffer = device.makeBuffer(
            bytes: array,
            length: bufferSize,
            options: options
        ) else {
            throw MetalTestError.bufferCreationFailed
        }
        
        return buffer
    }
    
    /// Creates an empty Metal buffer with a specified size
    /// - Parameters:
    ///   - length: The length of the buffer in bytes
    ///   - options: The resource options for the buffer
    /// - Returns: The created Metal buffer
    /// - Throws: MetalTestError.bufferCreationFailed if the buffer creation fails
    public func createBuffer(
        length: Int,
        options: MTLResourceOptions = []
    ) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(
            length: length,
            options: options
        ) else {
            throw MetalTestError.bufferCreationFailed
        }
        
        return buffer
    }
    
    /// Extracts data from a Metal buffer as an array of values
    /// - Parameters:
    ///   - buffer: The buffer to extract data from
    ///   - type: The type of the data to extract
    ///   - count: The number of elements to extract
    /// - Returns: The extracted data as an array
    public func getBufferData<T>(
        from buffer: MTLBuffer,
        type: T.Type,
        count: Int
    ) -> [T] {
        // Get a pointer to the buffer contents
        let data = buffer.contents().bindMemory(
            to: type,
            capacity: count
        )
        
        // Copy the data into an array
        let bufferPointer = UnsafeBufferPointer(start: data, count: count)
        return Array(bufferPointer)
    }
    
    // MARK: - Shader Execution
    
    /// Creates a compute pipeline state for a function
    /// - Parameter functionName: The name of the compute function
    /// - Returns: The created compute pipeline state
    /// - Throws: MetalTestError if the pipeline creation fails
    public func createComputePipelineState(
        for functionName: String
    ) throws -> MTLComputePipelineState {
        // Get the compute function
        guard let function = defaultLibrary.makeFunction(name: functionName) else {
            throw MetalTestError.functionNotFound(name: functionName)
        }
        
        // Create the compute pipeline state
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw MetalTestError.pipelineCreationFailed(error: error)
        }
    }
    
    /// Runs a compute shader
    /// - Parameters:
    ///   - pipelineState: The compute pipeline state to use
    ///   - inputBuffers: The input buffers to bind to the compute shader
    ///   - outputBuffers: The output buffers to bind to the compute shader
    ///   - threadgroupSize: The size of each threadgroup
    ///   - threadgroupCount: The number of threadgroups to dispatch
    /// - Throws: MetalTestError if the shader execution fails
    public func runComputeShader(
        pipelineState: MTLComputePipelineState,
        inputBuffers: [(index: Int, buffer: MTLBuffer)],
        outputBuffers: [(index: Int, buffer: MTLBuffer)],
        threadgroupSize: MTLSize,
        threadgroupCount: MTLSize
    ) throws {
        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalTestError.commandBufferCreationFailed
        }
        
        // Create a compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalTestError.commandEncoderCreationFailed
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Set input buffers
        for (index, buffer) in inputBuffers {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Set output buffers
        for (index, buffer) in outputBuffers {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Dispatch threadgroups
        computeEncoder.dispatchThreadgroups(
            threadgroupCount,
            threadsPerThreadgroup: threadgroupSize
        )
        
        computeEncoder.endEncoding()
        
        // Execute the command buffer
        var executionError: Error? = nil
        commandBuffer.addCompletedHandler { buffer in
            if buffer.status == .error {
                executionError = buffer.error
            }
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if let error = executionError {
            throw MetalTestError.executionFailed(error: error)
        }
    }
    
    /// Runs a compute shader with a 1D grid
    /// - Parameters:
    ///   - functionName: The name of the compute function
    ///   - inputBuffers: The input buffers to bind to the compute shader
    ///   - outputBuffers: The output buffers to bind to the compute shader
    ///   - count: The number of elements to process
    ///   - threadsPerThreadgroup: The number of threads per threadgroup
    /// - Throws: MetalTestError if the shader execution fails
    public func runComputeShader1D(
        functionName: String,
        inputBuffers: [(index: Int, buffer: MTLBuffer)],
        outputBuffers: [(index: Int, buffer: MTLBuffer)],
        count: Int,
        threadsPerThreadgroup: Int = 256
    ) throws {
        // Create the compute pipeline state
        let pipelineState = try createComputePipelineState(for: functionName)
        
        // Calculate threadgroup sizes
        let threadgroupSize = MTLSize(
            width: threadsPerThreadgroup,
            height: 1,
            depth: 1
        )
        
        let threadgroupCount = MTLSize(
            width: (count + threadsPerThreadgroup - 1) / threadsPerThreadgroup,
            height: 1,
            depth: 1
        )
        
        // Run the compute shader
        try runComputeShader(
            pipelineState: pipelineState,
            inputBuffers: inputBuffers,
            outputBuffers: outputBuffers,
            threadgroupSize: threadgroupSize,
            threadgroupCount: threadgroupCount
        )
    }
    
    /// Runs a compute shader with a 2D grid
    /// - Parameters:
    ///   - functionName: The name of the compute function
    ///   - inputBuffers: The input buffers to bind to the compute shader
    ///   - outputBuffers: The output buffers to bind to the compute shader
    ///   - width: The width of the 2D grid
    ///   - height: The height of the 2D grid
    ///   - threadsPerThreadgroup: The size of each threadgroup
    /// - Throws: MetalTestError if the shader execution fails
    public func runComputeShader2D(
        functionName: String,
        inputBuffers: [(index: Int, buffer: MTLBuffer)],
        outputBuffers: [(index: Int, buffer: MTLBuffer)],
        width: Int,
        height: Int,
        threadsPerThreadgroup: MTLSize = MTLSize(width: 16, height: 16, depth: 1)
    ) throws {
        // Create the compute pipeline state
        let pipelineState = try createComputePipelineState(for: functionName)
        
        // Calculate threadgroup count
        let threadgroupCount = MTLSize(
            width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        
        // Run the compute shader
        try runComputeShader(
            pipelineState: pipelineState,
            inputBuffers: inputBuffers,
            outputBuffers: outputBuffers,
            threadgroupSize: threadsPerThreadgroup,
            threadgroupCount: threadgroupCount
        )
    }
    
    // MARK: - Verification
    
    /// Compares two arrays for equality within a tolerance
    /// - Parameters:
    ///   - actual: The actual values from the Metal shader
    ///   - expected: The expected values
    ///   - tolerance: The maximum allowed difference between values
    /// - Returns: True if the arrays match within the tolerance
    /// - Throws: MetalTestError.resultMismatch if the arrays don't match
    public func compareArrays<T: FloatingPoint>(
        actual: [T],
        expected: [T],
        tolerance: T
    ) throws -> Bool {
        // Check that the arrays have the same length
        guard actual.count == expected.count else {
            throw MetalTestError.resultMismatch(
                description: "Array length mismatch: \(actual.count) vs \(expected.count)"
            )
        }
        
        // Compare each element
        for (index, (a, e)) in zip(actual, expected).enumerated() {
            if abs(a - e) > tolerance {
                throw MetalTestError.resultMismatch(
                    description: "Value mismatch at index \(index): \(a) vs \(e) (tolerance: \(tolerance))"
                )
            }
        }
        
        return true
    }
    
    /// Compares two arrays for exact equality
    /// - Parameters:
    ///   - actual: The actual values from the Metal shader
    ///   - expected: The expected values
    /// - Returns: True if the arrays match exactly
    /// - Throws: MetalTestError.resultMismatch if the arrays don't match
    public func compareArrays<T: Equatable>(
        actual: [T],
        expected: [T]
    ) throws -> Bool {
        // Check that the arrays have the same length
        guard actual.count == expected.count else {
            throw MetalTestError.resultMismatch(
                description: "Array length mismatch: \(actual.count) vs \(expected.count)"
            )
        }
        
        // Compare each element
        for (index, (a, e)) in zip(actual, expected).enumerated() {
            if a != e {
                throw MetalTestError.resultMismatch(
                    description: "Value mismatch at index \(index): \(a) vs \(e)"
                )
            }
        }
        
        return true
    }
    
    /// Checks if Metal is available on the current device
    /// - Returns: True if Metal is available
    public static func isMetalAvailable() -> Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Skips a test if Metal is not available
    /// - Parameter message: The message to display when skipping the test
    public func skipIfMetalUnavailable(_ message: String = "Metal is not available on this device") {
        if !MetalTestUtility.isMetalAvailable() {
            throw XCTSkip(message)
        }
        
        // Also check if we should skip Metal tests based on the test configuration
        if !TestConfig.shared.useMetalWhenAvailable {
            throw XCTSkip("Metal tests are disabled in the test configuration")
        }
    }
    
    /// Creates a Metal test utility
    /// - Returns: The created Metal test utility
    /// - Throws: MetalTestError if Metal is not available
    public func createMetalTestUtility() throws -> MetalTestUtility {
        // Skip the test if Metal is not available
        skipIfMetalUnavailable()
        
        // Create the Metal test utility
        return try MetalTestUtility()
    }
} 