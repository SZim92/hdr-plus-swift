import XCTest
import Foundation

/// TestHelper provides utility functions for common testing needs across the HDR+ Swift project.
/// This centralizes testing utilities to make tests easier to write and maintain.
public struct TestHelper {
    
    // MARK: - Test Resource Management
    
    /// Get the URL for a test resource file in the specified bundle
    /// - Parameters:
    ///   - name: The resource name (without extension)
    ///   - extension: The file extension
    ///   - bundle: The bundle containing the resource (default: Bundle.module)
    /// - Returns: URL to the resource
    /// - Throws: TestHelperError if the resource could not be found
    public static func urlForResource(
        named name: String,
        withExtension extension: String,
        in bundle: Bundle = Bundle.module
    ) throws -> URL {
        guard let url = bundle.url(forResource: name, withExtension: `extension`) else {
            throw TestHelperError.resourceNotFound(name: name, extension: `extension`)
        }
        return url
    }
    
    /// Get test data from a resource file
    /// - Parameters:
    ///   - name: The resource name (without extension)
    ///   - extension: The file extension
    ///   - bundle: The bundle containing the resource (default: Bundle.module)
    /// - Returns: The data from the resource
    /// - Throws: TestHelperError if the resource could not be loaded
    public static func dataFromResource(
        named name: String,
        withExtension extension: String,
        in bundle: Bundle = Bundle.module
    ) throws -> Data {
        let url = try urlForResource(named: name, withExtension: `extension`, in: bundle)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw TestHelperError.resourceLoadFailed(name: name, extension: `extension`, underlyingError: error)
        }
    }
    
    /// Load a JSON resource and decode it to the specified type
    /// - Parameters:
    ///   - name: The JSON resource name (without extension)
    ///   - type: The type to decode into
    ///   - bundle: The bundle containing the resource (default: Bundle.module)
    /// - Returns: The decoded object
    /// - Throws: TestHelperError if the resource could not be loaded or decoded
    public static func loadJSON<T: Decodable>(
        named name: String,
        as type: T.Type,
        from bundle: Bundle = Bundle.module
    ) throws -> T {
        let data = try dataFromResource(named: name, withExtension: "json", in: bundle)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw TestHelperError.jsonDecodingFailed(name: name, underlyingError: error)
        }
    }
    
    // MARK: - Temporary Files
    
    /// Create a temporary file with the given data
    /// - Parameters:
    ///   - data: The data to write to the file
    ///   - extension: The file extension to use (default: "tmp")
    /// - Returns: URL to the temporary file
    /// - Throws: TestHelperError if the file could not be created
    public static func createTemporaryFile(
        with data: Data,
        extension: String = "tmp"
    ) throws -> URL {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileName = UUID().uuidString
        let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName).appendingPathExtension(`extension`)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            throw TestHelperError.tempFileCreationFailed(underlyingError: error)
        }
    }
    
    /// Create a temporary directory
    /// - Returns: URL to the temporary directory
    /// - Throws: TestHelperError if the directory could not be created
    public static func createTemporaryDirectory() throws -> URL {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let uniqueDirectoryName = UUID().uuidString
        let directoryURL = temporaryDirectoryURL.appendingPathComponent(uniqueDirectoryName)
        
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return directoryURL
        } catch {
            throw TestHelperError.tempDirectoryCreationFailed(underlyingError: error)
        }
    }
    
    // MARK: - Test Assertions
    
    /// Assert that two floating point arrays are approximately equal
    /// - Parameters:
    ///   - lhs: First array
    ///   - rhs: Second array
    ///   - accuracy: The accuracy for comparison
    ///   - message: Optional message for the assertion
    ///   - file: The file where the assertion occurs
    ///   - line: The line where the assertion occurs
    public static func assertArraysEqual<T: FloatingPoint>(
        _ lhs: [T],
        _ rhs: [T],
        accuracy: T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Check array sizes
        XCTAssertEqual(lhs.count, rhs.count, "Arrays have different counts: \(lhs.count) vs \(rhs.count)", file: file, line: line)
        guard lhs.count == rhs.count else { return }
        
        // Check elements
        for (index, (left, right)) in zip(lhs, rhs).enumerated() {
            XCTAssertEqual(
                left, right,
                accuracy: accuracy,
                "Arrays differ at index \(index): \(left) vs \(right). \(message())",
                file: file,
                line: line
            )
        }
    }
    
    /// Wait for a condition to be true with timeout
    /// - Parameters:
    ///   - timeout: Timeout in seconds
    ///   - description: Description of what we're waiting for
    ///   - condition: The condition to check
    /// - Returns: True if the condition was met, false if timed out
    @discardableResult
    public static func waitFor(
        timeout: TimeInterval,
        description: String,
        condition: @escaping () -> Bool
    ) -> Bool {
        let startTime = Date()
        
        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }
            
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        return true
    }
    
    // MARK: - Test Measurement
    
    /// Measure execution time of a block
    /// - Parameters:
    ///   - description: Description of what's being measured
    ///   - block: The block to measure
    /// - Returns: Time interval in seconds
    @discardableResult
    public static func measureExecutionTime(
        description: String,
        block: () -> Void
    ) -> TimeInterval {
        let startTime = Date()
        block()
        let endTime = Date()
        let timeInterval = endTime.timeIntervalSince(startTime)
        
        print("[\(description)] Execution time: \(timeInterval) seconds")
        return timeInterval
    }
    
    /// Measure memory usage of a block
    /// - Parameter block: The block to measure
    /// - Returns: Peak memory usage in bytes
    public static func measureMemoryUsage(
        block: () -> Void
    ) -> UInt64 {
        // Perform initial garbage collection
        autoreleasepool {
            // Do nothing, just ensure memory gets released
        }
        
        let startMemory = currentMemoryUsage()
        
        block()
        
        // Ensure everything is deallocated properly
        autoreleasepool {
            // Do nothing, just ensure memory gets released
        }
        
        let endMemory = currentMemoryUsage()
        let usedMemory = endMemory > startMemory ? endMemory - startMemory : 0
        
        print("Memory usage: \(usedMemory) bytes")
        return usedMemory
    }
    
    // Get current memory usage (simplified version)
    private static func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { (machPtr: UnsafeMutablePointer<integer_t>) in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    machPtr,
                    &count
                )
            }
        }
        
        if result == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - Errors

/// Errors that can occur in TestHelper
public enum TestHelperError: Error, CustomStringConvertible {
    case resourceNotFound(name: String, extension: String)
    case resourceLoadFailed(name: String, extension: String, underlyingError: Error)
    case jsonDecodingFailed(name: String, underlyingError: Error)
    case tempFileCreationFailed(underlyingError: Error)
    case tempDirectoryCreationFailed(underlyingError: Error)
    
    public var description: String {
        switch self {
        case .resourceNotFound(let name, let ext):
            return "Resource not found: \(name).\(ext)"
        case .resourceLoadFailed(let name, let ext, let error):
            return "Failed to load resource \(name).\(ext): \(error.localizedDescription)"
        case .jsonDecodingFailed(let name, let error):
            return "Failed to decode JSON from \(name).json: \(error.localizedDescription)"
        case .tempFileCreationFailed(let error):
            return "Failed to create temporary file: \(error.localizedDescription)"
        case .tempDirectoryCreationFailed(let error):
            return "Failed to create temporary directory: \(error.localizedDescription)"
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    
    /// Measures the execution time of a test block and verifies it's within acceptable limits
    /// - Parameters:
    ///   - description: Description of what's being measured
    ///   - expectedTime: The expected execution time in seconds
    ///   - allowedDeviation: Allowed deviation as a factor (1.5 means 50% deviation allowed)
    ///   - block: The block to measure
    /// - Returns: The actual execution time
    @discardableResult
    public func assertPerformance(
        _ description: String,
        expectedTime: TimeInterval,
        allowedDeviation: Double = 1.5,
        block: () -> Void
    ) -> TimeInterval {
        let executionTime = TestHelper.measureExecutionTime(description: description, block: block)
        
        let maxTime = expectedTime * allowedDeviation
        XCTAssertLessThanOrEqual(
            executionTime, maxTime,
            "Performance test '\(description)' took too long: \(executionTime) seconds. Expected max: \(maxTime) seconds"
        )
        
        return executionTime
    }
    
    /// Run a test that requires a temporary directory
    /// - Parameter testBlock: The test block that receives the temp directory URL
    public func withTemporaryDirectory(_ testBlock: (URL) throws -> Void) throws {
        let tempDirURL = try TestHelper.createTemporaryDirectory()
        defer {
            // Clean up after the test
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        
        try testBlock(tempDirURL)
    }
    
    /// Check if the test should be skipped on CI
    /// - Parameter message: Optional message explaining why the test is skipped on CI
    /// - Returns: True if running on CI, false otherwise
    @discardableResult
    public func skipOnCI(_ message: String = "Test skipped on CI") -> Bool {
        // Check common CI environment variables
        let isCI = ProcessInfo.processInfo.environment["CI"] != nil ||
                   ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                   ProcessInfo.processInfo.environment["TRAVIS"] != nil ||
                   ProcessInfo.processInfo.environment["JENKINS_URL"] != nil
        
        if isCI {
            throw XCTSkip(message)
        }
        
        return isCI
    }
    
    /// Skip a test if it requires excessive resources
    /// - Parameter message: Message explaining why the test requires excessive resources
    public func skipIfExcessiveResources(_ message: String = "Test requires excessive resources") {
        let shouldSkip = ProcessInfo.processInfo.environment["SKIP_RESOURCE_INTENSIVE"] != nil
        
        if shouldSkip {
            throw XCTSkip(message)
        }
    }
}

// For memory usage measurement we need to import Darwin framework for task_info
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif 