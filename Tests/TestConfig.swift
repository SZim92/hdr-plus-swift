import Foundation
import XCTest

/// Central configuration manager for all tests in the HDR+ Swift project.
/// This class provides consistent access to test resources, directories, and settings.
public final class TestConfig {
    /// The shared singleton instance
    public static let shared = TestConfig()
    
    // MARK: - Directories
    
    /// Base directory for all test resources
    public let testResourcesDir: URL
    
    /// Directory for reference images used in visual tests
    public let referenceImagesDir: URL
    
    /// Directory for test fixtures and temporary files
    public let fixturesDir: URL
    
    /// Directory for failed test artifacts (diffs, etc.)
    public let failedTestArtifactsDir: URL
    
    /// Directory for performance test baselines
    public let performanceBaselinesDir: URL
    
    /// Directory for Metal test resources
    public let metalTestResourcesDir: URL
    
    // MARK: - Test settings
    
    /// Whether to save visual test failures as artifacts
    public var saveFailedVisualTests: Bool
    
    /// Whether to update reference images automatically when they don't exist
    public var updateReferenceImagesAutomatically: Bool
    
    /// Whether to log verbose output during tests
    public var verboseLogging: Bool
    
    /// Maximum acceptable percentage difference for image comparison in visual tests
    public var defaultImageComparisonTolerance: Double
    
    /// Whether to skip tests that require Metal when Metal is not available
    public var skipMetalTestsWhenUnavailable: Bool
    
    /// Performance test acceptable deviation from baseline as a percentage (0.2 = 20%)
    public var performanceAcceptableDeviation: Double
    
    // MARK: - Initialization
    
    private init() {
        // Set up base directories
        let fileManager = FileManager.default
        
        // Determine base test directory (either from environment variable or default)
        if let testDirEnv = ProcessInfo.processInfo.environment["HDR_PLUS_TEST_DIR"] {
            self.testResourcesDir = URL(fileURLWithPath: testDirEnv)
        } else {
            // Default: Use the current working directory with Tests subdirectory
            let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            
            // Look for Tests directory
            if fileManager.fileExists(atPath: currentDir.appendingPathComponent("Tests").path) {
                self.testResourcesDir = currentDir.appendingPathComponent("Tests/TestResources")
            } else {
                // Fallback to temp directory if Tests directory not found
                self.testResourcesDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("HDRPlusTests/TestResources")
            }
        }
        
        // Set up subdirectories
        self.referenceImagesDir = testResourcesDir.appendingPathComponent("ReferenceImages")
        self.fixturesDir = testResourcesDir.appendingPathComponent("Fixtures")
        self.failedTestArtifactsDir = testResourcesDir.appendingPathComponent("FailedTestArtifacts")
        self.performanceBaselinesDir = testResourcesDir.appendingPathComponent("PerformanceBaselines")
        self.metalTestResourcesDir = testResourcesDir.appendingPathComponent("MetalResources")
        
        // Set up test settings from environment variables or defaults
        self.saveFailedVisualTests = getBoolEnv("HDR_PLUS_SAVE_FAILED_VISUAL_TESTS", defaultValue: true)
        self.updateReferenceImagesAutomatically = getBoolEnv("HDR_PLUS_UPDATE_REFERENCE_IMAGES", defaultValue: true)
        self.verboseLogging = getBoolEnv("HDR_PLUS_TEST_VERBOSE", defaultValue: false)
        self.defaultImageComparisonTolerance = getDoubleEnv("HDR_PLUS_IMAGE_COMPARISON_TOLERANCE", defaultValue: 0.01)
        self.skipMetalTestsWhenUnavailable = getBoolEnv("HDR_PLUS_SKIP_METAL_TESTS", defaultValue: true)
        self.performanceAcceptableDeviation = getDoubleEnv("HDR_PLUS_PERFORMANCE_DEVIATION", defaultValue: 0.2)
        
        // Create directories if they don't exist
        createDirectories()
    }
    
    // MARK: - Directory Management
    
    /// Creates all required test directories if they don't exist
    public func createDirectories() {
        let fileManager = FileManager.default
        let directories = [
            testResourcesDir,
            referenceImagesDir,
            fixturesDir,
            failedTestArtifactsDir,
            performanceBaselinesDir,
            metalTestResourcesDir
        ]
        
        for directory in directories {
            do {
                if !fileManager.fileExists(atPath: directory.path) {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                    logVerbose("Created directory: \(directory.path)")
                }
            } catch {
                print("Error creating directory \(directory.path): \(error)")
            }
        }
    }
    
    /// Gets the path to a reference image for a given test.
    /// - Parameters:
    ///   - name: The name of the reference image.
    ///   - testClass: The test class requesting the reference.
    /// - Returns: URL for the reference image.
    public func referenceImageURL(for name: String, in testClass: AnyClass) -> URL {
        let className = String(describing: testClass)
        return referenceImagesDir
            .appendingPathComponent(className)
            .appendingPathComponent("\(name).png")
    }
    
    /// Gets the path to a failed test artifact for a given test.
    /// - Parameters:
    ///   - name: The name of the failed test.
    ///   - testClass: The test class that produced the failure.
    /// - Returns: URL for the failed test artifact.
    public func failedTestArtifactURL(for name: String, in testClass: AnyClass) -> URL {
        let className = String(describing: testClass)
        return failedTestArtifactsDir
            .appendingPathComponent(className)
            .appendingPathComponent("\(name).png")
    }
    
    /// Gets the path to a performance baseline for a given test.
    /// - Parameters:
    ///   - name: The name of the performance test.
    ///   - testClass: The test class that produced the baseline.
    /// - Returns: URL for the performance baseline.
    public func performanceBaselineURL(for name: String, in testClass: AnyClass) -> URL {
        let className = String(describing: testClass)
        return performanceBaselinesDir
            .appendingPathComponent(className)
            .appendingPathComponent("\(name).json")
    }
    
    // MARK: - Utilities
    
    /// Log a message when verbose logging is enabled
    /// - Parameter message: The message to log
    public func logVerbose(_ message: String) {
        if verboseLogging {
            print("[TestConfig] \(message)")
        }
    }
    
    // MARK: - Environment Variable Helpers
    
    /// Gets a Boolean environment variable or returns the default value.
    /// - Parameters:
    ///   - name: The name of the environment variable.
    ///   - defaultValue: The default value to return if the environment variable is not set.
    /// - Returns: The Boolean value of the environment variable or the default value.
    private func getBoolEnv(_ name: String, defaultValue: Bool) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            return defaultValue
        }
        
        let lowercasedValue = value.lowercased()
        return lowercasedValue == "true" || lowercasedValue == "yes" || lowercasedValue == "1"
    }
    
    /// Gets a Double environment variable or returns the default value.
    /// - Parameters:
    ///   - name: The name of the environment variable.
    ///   - defaultValue: The default value to return if the environment variable is not set.
    /// - Returns: The Double value of the environment variable or the default value.
    private func getDoubleEnv(_ name: String, defaultValue: Double) -> Double {
        guard let value = ProcessInfo.processInfo.environment[name],
              let doubleValue = Double(value) else {
            return defaultValue
        }
        
        return doubleValue
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Access to the shared test configuration from any test case
    public var testConfig: TestConfig {
        return TestConfig.shared
    }
} 