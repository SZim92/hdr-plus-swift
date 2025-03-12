import Foundation
import XCTest

/// TestConfig provides centralized configuration for all tests in the HDR+ Swift project.
/// This allows for consistent test behavior and easier maintenance.
public class TestConfig {
    
    // MARK: - Singleton
    
    /// Shared instance of the test configuration
    public static let shared = TestConfig()
    
    // MARK: - Properties
    
    /// Base directory for test resources
    public let resourcesDirectory: URL
    
    /// Directory for reference images used in visual tests
    public let referenceImagesDirectory: URL
    
    /// Directory for failed test images
    public let failedImagesDirectory: URL
    
    /// Directory for difference images generated during visual tests
    public let diffImagesDirectory: URL
    
    /// Directory for test fixtures
    public let fixturesDirectory: URL
    
    /// Directory for performance test results
    public let performanceResultsDirectory: URL
    
    /// Directory for temporary test files
    public let temporaryDirectory: URL
    
    /// Default tolerance for image comparison in visual tests
    public let defaultImageComparisonTolerance: Double
    
    /// Whether to save failed images in visual tests
    public let saveFailedImages: Bool
    
    /// Whether to generate difference images in visual tests
    public let generateDiffImages: Bool
    
    /// Whether to automatically update reference images when visual tests fail
    public let updateReferenceImagesAutomatically: Bool
    
    /// Whether tests are running in CI environment
    public let isRunningInCI: Bool
    
    /// Whether to enable verbose logging in tests
    public let verboseLogging: Bool
    
    /// Whether to use accelerated Metal testing when available
    public let useMetalWhenAvailable: Bool
    
    /// Maximum memory usage allowed for performance tests (in MB)
    public let maxMemoryUsageMB: Int
    
    /// Maximum execution time allowed for performance tests (in seconds)
    public let maxExecutionTimeSeconds: Double
    
    /// Number of warm-up iterations for performance tests
    public let performanceTestWarmupIterations: Int
    
    /// Number of measurement iterations for performance tests
    public let performanceTestMeasurementIterations: Int
    
    // MARK: - Initialization
    
    private init() {
        // Get environment variables if they exist
        let env = ProcessInfo.processInfo.environment
        
        // Determine base test directory
        let baseTestDirectory: URL
        if let testDataPath = env["HDR_TEST_DATA_PATH"] {
            baseTestDirectory = URL(fileURLWithPath: testDataPath)
        } else {
            baseTestDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("HDRPlusTests")
        }
        
        // Set up directory paths
        resourcesDirectory = baseTestDirectory.appendingPathComponent("Resources")
        referenceImagesDirectory = baseTestDirectory.appendingPathComponent("ReferenceImages")
        failedImagesDirectory = baseTestDirectory.appendingPathComponent("FailedImages")
        diffImagesDirectory = baseTestDirectory.appendingPathComponent("DiffImages")
        fixturesDirectory = baseTestDirectory.appendingPathComponent("Fixtures")
        performanceResultsDirectory = baseTestDirectory.appendingPathComponent("PerformanceResults")
        temporaryDirectory = baseTestDirectory.appendingPathComponent("Temp")
        
        // Set up visual test configurations
        defaultImageComparisonTolerance = Double(env["HDR_IMAGE_COMPARISON_TOLERANCE"] ?? "0.01") ?? 0.01
        saveFailedImages = env["HDR_SAVE_FAILED_IMAGES"]?.lowercased() != "false"
        generateDiffImages = env["HDR_GENERATE_DIFF_IMAGES"]?.lowercased() != "false"
        updateReferenceImagesAutomatically = env["HDR_UPDATE_REFERENCE_IMAGES"]?.lowercased() == "true"
        
        // Set up general test configurations
        isRunningInCI = env["CI"]?.lowercased() == "true"
        verboseLogging = env["HDR_VERBOSE_LOGGING"]?.lowercased() == "true"
        useMetalWhenAvailable = env["HDR_USE_METAL"]?.lowercased() != "false"
        
        // Set up performance test configurations
        maxMemoryUsageMB = Int(env["HDR_MAX_MEMORY_USAGE_MB"] ?? "1024") ?? 1024
        maxExecutionTimeSeconds = Double(env["HDR_MAX_EXECUTION_TIME_SECONDS"] ?? "10.0") ?? 10.0
        performanceTestWarmupIterations = Int(env["HDR_PERFORMANCE_WARMUP_ITERATIONS"] ?? "3") ?? 3
        performanceTestMeasurementIterations = Int(env["HDR_PERFORMANCE_MEASUREMENT_ITERATIONS"] ?? "10") ?? 10
        
        // Create directories if they don't exist
        createDirectories()
    }
    
    // MARK: - Directory Management
    
    /// Creates the necessary directories for tests
    public func createDirectories() {
        let fileManager = FileManager.default
        let directories = [
            resourcesDirectory,
            referenceImagesDirectory,
            failedImagesDirectory,
            diffImagesDirectory,
            fixturesDirectory,
            performanceResultsDirectory,
            temporaryDirectory
        ]
        
        for directory in directories {
            do {
                if !fileManager.fileExists(atPath: directory.path) {
                    try fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
            } catch {
                print("Error creating directory at \(directory.path): \(error)")
            }
        }
    }
    
    /// Cleans up temporary test directories
    public func cleanupTemporaryDirectories() {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: temporaryDirectory.path) {
                try fileManager.removeItem(at: temporaryDirectory)
                try fileManager.createDirectory(
                    at: temporaryDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        } catch {
            print("Error cleaning up temporary directory: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns the reference image URL for a given test name
    /// - Parameters:
    ///   - testName: The name of the test
    ///   - testClass: The test class
    /// - Returns: URL for the reference image
    public func referenceImageURL(for testName: String, in testClass: XCTestCase.Type) -> URL {
        let className = String(describing: testClass)
        return referenceImagesDirectory
            .appendingPathComponent(className)
            .appendingPathComponent("\(testName).png")
    }
    
    /// Returns the failed image URL for a given test name
    /// - Parameters:
    ///   - testName: The name of the test
    ///   - testClass: The test class
    /// - Returns: URL for the failed image
    public func failedImageURL(for testName: String, in testClass: XCTestCase.Type) -> URL {
        let className = String(describing: testClass)
        return failedImagesDirectory
            .appendingPathComponent(className)
            .appendingPathComponent("\(testName).png")
    }
    
    /// Returns the diff image URL for a given test name
    /// - Parameters:
    ///   - testName: The name of the test
    ///   - testClass: The test class
    /// - Returns: URL for the diff image
    public func diffImageURL(for testName: String, in testClass: XCTestCase.Type) -> URL {
        let className = String(describing: testClass)
        return diffImagesDirectory
            .appendingPathComponent(className)
            .appendingPathComponent("\(testName).png")
    }
    
    /// Returns a URL for a test resource
    /// - Parameter name: The name of the resource
    /// - Returns: URL for the resource
    public func resourceURL(for name: String) -> URL {
        return resourcesDirectory.appendingPathComponent(name)
    }
    
    /// Returns a URL for a performance result file
    /// - Parameters:
    ///   - testName: The name of the performance test
    ///   - testClass: The test class
    /// - Returns: URL for the performance result
    public func performanceResultURL(for testName: String, in testClass: XCTestCase.Type) -> URL {
        let className = String(describing: testClass)
        return performanceResultsDirectory
            .appendingPathComponent(className)
            .appendingPathComponent("\(testName).json")
    }
    
    /// Logs a message if verbose logging is enabled
    /// - Parameter message: The message to log
    public func logVerbose(_ message: String) {
        if verboseLogging {
            print("[HDR+ Test] \(message)")
        }
    }
    
    /// Gets a temporary directory for a specific test
    /// - Parameters:
    ///   - testName: The name of the test
    ///   - testClass: The test class
    /// - Returns: URL for the temporary directory
    public func temporaryDirectory(for testName: String, in testClass: XCTestCase.Type) -> URL {
        let className = String(describing: testClass)
        let tempDir = temporaryDirectory
            .appendingPathComponent(className)
            .appendingPathComponent(testName)
        
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        return tempDir
    }
}

/// Extension to XCTestCase to provide easy access to test configuration
extension XCTestCase {
    /// The test configuration for this test case
    var testConfig: TestConfig {
        return TestConfig.shared
    }
} 