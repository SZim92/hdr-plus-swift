import Foundation
import XCTest

/// TestConfig provides centralized configuration settings for all tests in the HDR+ Swift project.
/// This makes it easier to maintain consistent test behavior across the project.
public class TestConfig {
    
    /// Shared instance for easy access
    public static let shared = TestConfig()
    
    // MARK: - Test Environment Settings
    
    /// Whether the tests are running in a CI environment
    public var isCI: Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil ||
               ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
               ProcessInfo.processInfo.environment["TRAVIS"] != nil ||
               ProcessInfo.processInfo.environment["JENKINS_URL"] != nil
    }
    
    /// Whether verbose logging is enabled
    public var verboseLogging: Bool {
        return ProcessInfo.processInfo.environment["VERBOSE_TESTING"] == "1" ||
               ProcessInfo.processInfo.environment["DEBUG"] == "1"
    }
    
    /// Whether to skip resource-intensive tests
    public var skipResourceIntensiveTests: Bool {
        return ProcessInfo.processInfo.environment["SKIP_RESOURCE_INTENSIVE"] == "1" ||
               isCI
    }
    
    /// Whether to skip tests that require Metal
    public var skipMetalTests: Bool {
        return ProcessInfo.processInfo.environment["SKIP_METAL_TESTS"] == "1" ||
               !isMetalAvailable
    }
    
    /// Whether Metal is available on the current device
    public private(set) lazy var isMetalAvailable: Bool = {
        // Check Metal availability by trying to create a Metal device
        #if os(macOS) || os(iOS)
        if let _ = MTLCreateSystemDefaultDevice() {
            return true
        }
        #endif
        return false
    }()
    
    // MARK: - Test Data Paths
    
    /// Directory for test resources
    public let testResourcesDir: URL = {
        // First, check for an environment variable specifying the test resources dir
        if let envPath = ProcessInfo.processInfo.environment["TEST_RESOURCES_DIR"] {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }
        
        // Otherwise use a default path relative to the current working directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return currentDir.appendingPathComponent("TestResources", isDirectory: true)
    }()
    
    /// Directory for test results
    public let testResultsDir: URL = {
        // First, check for an environment variable
        if let envPath = ProcessInfo.processInfo.environment["TEST_RESULTS_DIR"] {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }
        
        // Otherwise use a default path
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return currentDir.appendingPathComponent("TestResults", isDirectory: true)
    }()
    
    /// Directory for test resources that are specific to the current run
    public lazy var tempTestDir: URL = {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("HDRPlusTests-\(UUID().uuidString)", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Warning: Failed to create temporary test directory: \(error)")
            // Fall back to the system temp dir
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        
        return tempDir
    }()
    
    // MARK: - Performance Settings
    
    /// Default timeout for async operations in tests
    public var defaultTimeout: TimeInterval = 30.0
    
    /// Default allowed deviation for performance tests (as a multiplier)
    public var defaultPerformanceDeviation: Double = 1.5
    
    /// Baseline performance metrics file path
    public lazy var performanceBaselinesPath: URL = {
        return testResourcesDir.appendingPathComponent("performance_baselines.json")
    }()
    
    // MARK: - Visual Test Settings
    
    /// Default pixel tolerance for image comparison
    public var defaultImageComparisonTolerance: Double = 0.02  // 2% pixel deviation allowed
    
    /// Whether to save diff images for failed visual tests
    public var saveDiffImages: Bool = true
    
    /// Directory for reference images in visual tests
    public lazy var referenceImagesDir: URL = {
        return testResourcesDir.appendingPathComponent("ReferenceImages", isDirectory: true)
    }()
    
    /// Directory for failed test images in visual tests
    public lazy var failedImagesDir: URL = {
        return testResultsDir.appendingPathComponent("FailedTests/Images", isDirectory: true)
    }()
    
    // MARK: - Initialization
    
    private init() {
        // Create directories if they don't exist
        createDirectoryIfNeeded(testResultsDir)
        createDirectoryIfNeeded(testResourcesDir)
        createDirectoryIfNeeded(referenceImagesDir)
        createDirectoryIfNeeded(failedImagesDir)
        
        // Load any custom configuration
        loadCustomConfig()
        
        if verboseLogging {
            printConfigSummary()
        }
    }
    
    private func createDirectoryIfNeeded(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("Warning: Failed to create directory \(url.path): \(error)")
            }
        }
    }
    
    private func loadCustomConfig() {
        // Look for a custom config file
        let configPath = testResourcesDir.appendingPathComponent("test_config.json")
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: configPath)
            let decoder = JSONDecoder()
            
            struct ConfigValues: Codable {
                var defaultTimeout: TimeInterval?
                var defaultPerformanceDeviation: Double?
                var defaultImageComparisonTolerance: Double?
                var saveDiffImages: Bool?
            }
            
            let configValues = try decoder.decode(ConfigValues.self, from: data)
            
            // Apply values that were found in the config file
            if let timeout = configValues.defaultTimeout {
                defaultTimeout = timeout
            }
            
            if let deviation = configValues.defaultPerformanceDeviation {
                defaultPerformanceDeviation = deviation
            }
            
            if let tolerance = configValues.defaultImageComparisonTolerance {
                defaultImageComparisonTolerance = tolerance
            }
            
            if let saveDiff = configValues.saveDiffImages {
                saveDiffImages = saveDiff
            }
            
        } catch {
            print("Warning: Failed to load custom test config from \(configPath): \(error)")
        }
    }
    
    private func printConfigSummary() {
        print("=== Test Configuration ===")
        print("- Running in CI: \(isCI)")
        print("- Metal available: \(isMetalAvailable)")
        print("- Skip resource-intensive tests: \(skipResourceIntensiveTests)")
        print("- Skip Metal tests: \(skipMetalTests)")
        print("- Resources directory: \(testResourcesDir.path)")
        print("- Results directory: \(testResultsDir.path)")
        print("- Default timeout: \(defaultTimeout) seconds")
        print("- Default performance deviation: \(defaultPerformanceDeviation)x")
        print("- Default image comparison tolerance: \(defaultImageComparisonTolerance * 100)%")
        print("==========================")
    }
    
    /// Reset temporary test directories
    public func resetTempDirectories() {
        do {
            try FileManager.default.removeItem(at: tempTestDir)
            // Re-create the directory
            try FileManager.default.createDirectory(
                at: tempTestDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Warning: Failed to reset temporary test directory: \(error)")
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    
    /// Get the TestConfig instance
    public var config: TestConfig {
        return TestConfig.shared
    }
    
    /// Skip test if it's running in CI
    public func skipOnCI(_ message: String = "Test skipped in CI environment") {
        if config.isCI {
            throw XCTSkip(message)
        }
    }
    
    /// Skip test if it requires excessive resources and we're configured to skip them
    public func skipIfResourceIntensive(_ message: String = "Test requires excessive resources") {
        if config.skipResourceIntensiveTests {
            throw XCTSkip(message)
        }
    }
    
    /// Skip test if it requires Metal and Metal isn't available or we're configured to skip Metal tests
    public func skipIfMetalUnavailable(_ message: String = "Test requires Metal API") {
        if config.skipMetalTests {
            throw XCTSkip(message)
        }
    }
    
    /// Log a message, but only if verbose logging is enabled
    public func logVerbose(_ message: String) {
        if config.verboseLogging {
            print("[VERBOSE] \(message)")
        }
    }
    
    /// Create a URL in the test resources directory
    public func resourceURL(forResource name: String, withExtension ext: String) -> URL {
        return config.testResourcesDir
            .appendingPathComponent(name)
            .appendingPathExtension(ext)
    }
    
    /// Create a URL in the temporary test directory
    public func tempURL(forFilename filename: String) -> URL {
        return config.tempTestDir.appendingPathComponent(filename)
    }
}

#if os(macOS) || os(iOS)
import Metal
#endif 