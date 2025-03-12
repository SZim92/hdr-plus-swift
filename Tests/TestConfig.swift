import Foundation
import XCTest

/// TestConfig provides centralized configuration for test parameters and settings
/// across the HDR+ Swift test suite.
struct TestConfig {
    /// Singleton instance of the test configuration
    static let shared = TestConfig()
    
    // MARK: - Environment Variables
    
    /// Check if a specific environment variable is set
    /// - Parameter name: The name of the environment variable
    /// - Returns: True if the environment variable is set and not empty
    static func hasEnvironmentVariable(_ name: String) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            return false
        }
        return !value.isEmpty
    }
    
    /// Get the value of an environment variable
    /// - Parameter name: The name of the environment variable
    /// - Returns: The value of the environment variable, or nil if not set
    static func environmentVariable(_ name: String) -> String? {
        return ProcessInfo.processInfo.environment[name]
    }
    
    /// Get the value of an environment variable as a Boolean
    /// - Parameter name: The name of the environment variable
    /// - Parameter defaultValue: The default value to return if the environment variable is not set
    /// - Returns: The Boolean value of the environment variable, or the default value if not set
    static func boolEnvironmentVariable(_ name: String, defaultValue: Bool = false) -> Bool {
        guard let value = environmentVariable(name)?.lowercased() else {
            return defaultValue
        }
        return ["true", "yes", "1"].contains(value)
    }
    
    /// Get the value of an environment variable as an Int
    /// - Parameter name: The name of the environment variable
    /// - Parameter defaultValue: The default value to return if the environment variable is not set
    /// - Returns: The Int value of the environment variable, or the default value if not set
    static func intEnvironmentVariable(_ name: String, defaultValue: Int) -> Int {
        guard let value = environmentVariable(name), let intValue = Int(value) else {
            return defaultValue
        }
        return intValue
    }
    
    /// Get the value of an environment variable as a Double
    /// - Parameter name: The name of the environment variable
    /// - Parameter defaultValue: The default value to return if the environment variable is not set
    /// - Returns: The Double value of the environment variable, or the default value if not set
    static func doubleEnvironmentVariable(_ name: String, defaultValue: Double) -> Double {
        guard let value = environmentVariable(name), let doubleValue = Double(value) else {
            return defaultValue
        }
        return doubleValue
    }
    
    // MARK: - Test Mode Configuration
    
    /// Whether the tests are running in CI mode
    let isRunningInCI: Bool
    
    /// Whether test reports should be generated
    let shouldGenerateReports: Bool
    
    /// Whether verbose logging is enabled
    let verboseLogging: Bool
    
    // MARK: - Visual Test Configuration
    
    /// The base directory for visual test resources
    let visualTestResourcesDir: URL
    
    /// The directory for reference images
    let referenceImagesDir: URL
    
    /// The directory for failed test artifacts
    let failedTestArtifactsDir: URL
    
    /// The tolerance for visual image comparisons (0.0-1.0)
    let visualTestTolerance: Double
    
    /// Whether to automatically update reference images when they don't exist
    let autoUpdateReferenceImages: Bool
    
    /// Whether to save diff images for failed visual tests
    let saveDiffImages: Bool
    
    // MARK: - Performance Test Configuration
    
    /// The base directory for performance test resources
    let performanceTestResourcesDir: URL
    
    /// The number of iterations to run for performance tests
    let performanceTestIterations: Int
    
    /// The tolerance for performance metrics (0.0-1.0)
    let performanceTestTolerance: Double
    
    /// Whether to track performance history
    let trackPerformanceHistory: Bool
    
    // MARK: - Metal Test Configuration
    
    /// Whether to skip Metal tests if Metal is not available
    let skipMetalTestsIfUnavailable: Bool
    
    /// Whether to run Metal tests even on simulators (where they might crash)
    let runMetalTestsOnSimulator: Bool
    
    // MARK: - Test Fixtures Configuration
    
    /// The base directory for test fixtures
    let testFixturesDir: URL
    
    /// Whether to clean up test fixtures after tests
    let cleanupTestFixtures: Bool
    
    // MARK: - Test Input Resources
    
    /// The base directory for test input resources
    let testInputsDir: URL
    
    /// The directory for pattern test images
    let patternImagesDir: URL
    
    /// The directory for RAW test images
    let rawImagesDir: URL
    
    /// The directory for burst sequence test images
    let burstImagesDir: URL
    
    // MARK: - Flaky Test Tracking
    
    /// Whether to track flaky tests
    let trackFlakyTests: Bool
    
    /// The number of retries for flaky tests
    let flakyTestRetries: Int
    
    /// The directory for flaky test tracking data
    let flakyTestsDir: URL
    
    // MARK: - Initialization
    
    private init() {
        // Test mode configuration
        self.isRunningInCI = TestConfig.boolEnvironmentVariable("HDR_TEST_CI_MODE", defaultValue: false)
        self.shouldGenerateReports = TestConfig.boolEnvironmentVariable("HDR_TEST_GENERATE_REPORTS", defaultValue: true)
        self.verboseLogging = TestConfig.boolEnvironmentVariable("HDR_TEST_VERBOSE", defaultValue: false)
        
        // Base directories
        let baseDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("HDRTests")
        let baseResourcesDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("TestResources")
        
        // Visual test configuration
        self.visualTestResourcesDir = baseResourcesDir.appendingPathComponent("VisualTests")
        self.referenceImagesDir = visualTestResourcesDir.appendingPathComponent("ReferenceImages")
        self.failedTestArtifactsDir = baseDir.appendingPathComponent("FailedTestArtifacts")
        self.visualTestTolerance = TestConfig.doubleEnvironmentVariable("HDR_VISUAL_TEST_TOLERANCE", defaultValue: 0.02)
        self.autoUpdateReferenceImages = TestConfig.boolEnvironmentVariable("HDR_AUTO_UPDATE_REFERENCE_IMAGES", defaultValue: false)
        self.saveDiffImages = TestConfig.boolEnvironmentVariable("HDR_SAVE_DIFF_IMAGES", defaultValue: true)
        
        // Performance test configuration
        self.performanceTestResourcesDir = baseResourcesDir.appendingPathComponent("PerformanceTests")
        self.performanceTestIterations = TestConfig.intEnvironmentVariable("HDR_PERFORMANCE_TEST_ITERATIONS", defaultValue: 10)
        self.performanceTestTolerance = TestConfig.doubleEnvironmentVariable("HDR_PERFORMANCE_TEST_TOLERANCE", defaultValue: 0.2)
        self.trackPerformanceHistory = TestConfig.boolEnvironmentVariable("HDR_TRACK_PERFORMANCE_HISTORY", defaultValue: true)
        
        // Metal test configuration
        self.skipMetalTestsIfUnavailable = TestConfig.boolEnvironmentVariable("HDR_SKIP_METAL_TESTS_IF_UNAVAILABLE", defaultValue: true)
        self.runMetalTestsOnSimulator = TestConfig.boolEnvironmentVariable("HDR_RUN_METAL_TESTS_ON_SIMULATOR", defaultValue: false)
        
        // Test fixtures configuration
        self.testFixturesDir = baseDir.appendingPathComponent("TestFixtures")
        self.cleanupTestFixtures = TestConfig.boolEnvironmentVariable("HDR_CLEANUP_TEST_FIXTURES", defaultValue: true)
        
        // Test input resources
        self.testInputsDir = baseResourcesDir.appendingPathComponent("TestInputs")
        self.patternImagesDir = testInputsDir.appendingPathComponent("Patterns")
        self.rawImagesDir = testInputsDir.appendingPathComponent("RAW")
        self.burstImagesDir = testInputsDir.appendingPathComponent("Bursts")
        
        // Flaky test tracking
        self.trackFlakyTests = TestConfig.boolEnvironmentVariable("HDR_TRACK_FLAKY_TESTS", defaultValue: true)
        self.flakyTestRetries = TestConfig.intEnvironmentVariable("HDR_FLAKY_TEST_RETRIES", defaultValue: 3)
        self.flakyTestsDir = baseDir.appendingPathComponent("FlakyTests")
    }
    
    // MARK: - Helper Methods
    
    /// Creates all required directories for the test configuration
    func createDirectories() {
        let fileManager = FileManager.default
        let directories = [
            visualTestResourcesDir,
            referenceImagesDir,
            failedTestArtifactsDir,
            performanceTestResourcesDir,
            testFixturesDir,
            testInputsDir,
            patternImagesDir,
            rawImagesDir,
            burstImagesDir,
            flakyTestsDir
        ]
        
        for directory in directories {
            do {
                if !fileManager.fileExists(atPath: directory.path) {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                }
            } catch {
                print("Warning: Failed to create directory at \(directory.path): \(error)")
            }
        }
    }
    
    /// Gets the reference image URL for a given test case
    /// - Parameters:
    ///   - name: The name of the reference image
    ///   - testCase: The test case that's requesting the reference image
    /// - Returns: The URL to the reference image
    func referenceImageURL(named name: String, for testCase: XCTestCase) -> URL {
        let className = String(describing: type(of: testCase))
        return referenceImagesDir
            .appendingPathComponent(className)
            .appendingPathComponent("\(name).png")
    }
    
    /// Gets the URL for a failed test artifact
    /// - Parameters:
    ///   - name: The name of the artifact
    ///   - testCase: The test case that's requesting the artifact
    /// - Returns: The URL to the artifact
    func failedTestArtifactURL(named name: String, for testCase: XCTestCase) -> URL {
        let className = String(describing: type(of: testCase))
        return failedTestArtifactsDir
            .appendingPathComponent(className)
            .appendingPathComponent("\(name)")
    }
    
    /// Gets the URL for a test input resource
    /// - Parameter name: The name of the resource
    /// - Returns: The URL to the resource
    func testInputURL(named name: String) -> URL {
        return testInputsDir.appendingPathComponent(name)
    }
    
    /// Gets the URL for a pattern image
    /// - Parameter name: The name of the pattern image
    /// - Returns: The URL to the pattern image
    func patternImageURL(named name: String) -> URL {
        return patternImagesDir.appendingPathComponent(name)
    }
    
    /// Gets the URL for a RAW image
    /// - Parameter name: The name of the RAW image
    /// - Returns: The URL to the RAW image
    func rawImageURL(named name: String) -> URL {
        return rawImagesDir.appendingPathComponent(name)
    }
    
    /// Gets the URL for a burst sequence
    /// - Parameter name: The name of the burst sequence
    /// - Returns: The URL to the burst sequence directory
    func burstSequenceURL(named name: String) -> URL {
        return burstImagesDir.appendingPathComponent(name)
    }
    
    /// Gets the URL for performance history data
    /// - Parameter name: The name of the performance metric
    /// - Returns: The URL to the performance history data
    func performanceHistoryURL(named name: String) -> URL {
        return performanceTestResourcesDir.appendingPathComponent("\(name)_history.json")
    }
    
    /// Gets the URL for flaky test data
    /// - Parameter testName: The name of the test
    /// - Returns: The URL to the flaky test data
    func flakyTestDataURL(named testName: String) -> URL {
        return flakyTestsDir.appendingPathComponent("\(testName).json")
    }
}

/// Extension to XCTestCase to provide easy access to test configuration
extension XCTestCase {
    /// The test configuration for this test case
    var testConfig: TestConfig {
        return TestConfig.shared
    }
} 