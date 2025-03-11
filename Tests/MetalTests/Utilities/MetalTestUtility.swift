import XCTest
import Metal
import Foundation

/// A utility class for testing Metal shaders
class MetalTestUtility {
    
    /// Shared device instance
    static let device = MTLCreateSystemDefaultDevice()
    
    /// Shared command queue
    static var commandQueue: MTLCommandQueue? {
        return device?.makeCommandQueue()
    }
    
    /// Metal testing not available error
    static let metalNotAvailableError = "Metal not available on this device"
    
    /**
     Check if Metal is available on this device
     
     - Returns: True if Metal is available, false otherwise
     */
    static func isMetalAvailable() -> Bool {
        return device != nil
    }
    
    /**
     Skip the current test if Metal is not available
     
     - Parameter testCase: The XCTestCase instance
     */
    static func skipIfMetalNotAvailable(testCase: XCTestCase) {
        guard isMetalAvailable() else {
            testCase.continueAfterFailure = true
            XCTFail(metalNotAvailableError)
            testCase.throwSkip("Skipping test: \(metalNotAvailableError)")
            return
        }
    }
    
    /**
     Create a Metal buffer from array data
     
     - Parameters:
        - array: The array to create a buffer from
        - options: The resource options
     - Returns: A Metal buffer containing the array data
     */
    static func createBuffer<T>(from array: [T], options: MTLResourceOptions = []) -> MTLBuffer? {
        guard let device = device else { return nil }
        
        let byteLength = array.count * MemoryLayout<T>.stride
        return device.makeBuffer(bytes: array, length: byteLength, options: options)
    }
    
    /**
     Load Metal shader from file
     
     - Parameters:
        - name: The name of the metal file (without extension)
        - functionName: The name of the function to load
     - Returns: A compute pipeline state for the shader function
     - Throws: Error if shader compilation fails
     */
    static func loadShader(name: String, functionName: String) throws -> MTLComputePipelineState? {
        guard let device = device else { return nil }
        
        // Get the Metal library from the bundle
        let bundle = Bundle(for: MetalTestUtility.self)
        guard let libraryURL = bundle.url(forResource: name, withExtension: "metal") else {
            throw NSError(domain: "MetalTestUtility", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal shader file not found: \(name).metal"])
        }
        
        let source = try String(contentsOf: libraryURL)
        let library = try device.makeLibrary(source: source, options: nil)
        
        guard let function = library.makeFunction(name: functionName) else {
            throw NSError(domain: "MetalTestUtility", code: 2, userInfo: [NSLocalizedDescriptionKey: "Metal function not found: \(functionName)"])
        }
        
        return try device.makeComputePipelineState(function: function)
    }
    
    /**
     Extract data from a Metal buffer
     
     - Parameters:
        - buffer: The Metal buffer to extract data from
        - count: The number of elements to extract
     - Returns: An array containing the data from the buffer
     */
    static func extractData<T>(from buffer: MTLBuffer, count: Int) -> [T] {
        let pointer = buffer.contents().bindMemory(to: T.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }
    
    /**
     Run a Metal compute shader with input and output buffers
     
     - Parameters:
        - pipelineState: The compute pipeline state
        - inputBuffers: Dictionary of input buffers with parameter names as keys
        - outputBuffers: Dictionary of output buffers with parameter names as keys
        - threadgroupSize: The threadgroup size
        - threadgroupCount: The threadgroup count
     - Throws: Error if execution fails
     */
    static func runShader(
        pipelineState: MTLComputePipelineState,
        inputBuffers: [String: MTLBuffer],
        outputBuffers: [String: MTLBuffer],
        threadgroupSize: MTLSize,
        threadgroupCount: MTLSize
    ) throws {
        guard let device = device, let commandQueue = commandQueue else {
            throw NSError(domain: "MetalTestUtility", code: 3, userInfo: [NSLocalizedDescriptionKey: metalNotAvailableError])
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw NSError(domain: "MetalTestUtility", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create command buffer or compute encoder"])
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Set input buffers
        var index = 0
        for (_, buffer) in inputBuffers {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
            index += 1
        }
        
        // Set output buffers
        for (_, buffer) in outputBuffers {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
            index += 1
        }
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

extension XCTestCase {
    func throwSkip(_ message: String) {
        guard #available(iOS 14.0, macOS 11.0, *) else {
            print("Test skipped: \(message)")
            return
        }
        throw XCTSkip(message)
    }
} 