import XCTest
import Foundation

/// TestQuarantine provides a way to manage flaky tests without affecting the actual codebase.
/// It allows tests to be temporarily marked as expected to fail, quarantined, or skipped
/// until they can be properly fixed.
public enum TestQuarantine {
    
    /// Status of a quarantined test
    public enum Status {
        /// Test is expected to fail, but we want to track it without breaking CI
        case expectedToFail
        
        /// Test is quarantined because it's flaky (sometimes passes, sometimes fails)
        case flaky(reason: String)
        
        /// Test should be skipped entirely (not executed)
        case skip(reason: String)
    }
    
    /// Registry of quarantined tests, mapping test identifiers to their status
    /// Format: "TestClassName.testMethodName"
    private static let quarantinedTests: [String: Status] = [
        // Add quarantined tests here
        //"HDRPipelineTests.testProcessImageBatch": .flaky(reason: "Fails randomly due to race condition"),
        //"AlignmentTests.testHighContrastAlignment": .expectedToFail,
        //"PerformanceTests.testLargeImageProcessing": .skip(reason: "Takes too long, only run locally"),
    ]
    
    /// List of all quarantined tests, for reference and reporting
    public static var allQuarantinedTests: [String] {
        return Array(quarantinedTests.keys)
    }
    
    /// Checks if a test is quarantined
    /// - Parameter testName: The full test name (ClassName.methodName)
    /// - Returns: The status if the test is quarantined, nil otherwise
    public static func statusForTest(_ testName: String) -> Status? {
        return quarantinedTests[testName]
    }
    
    /// Checks if a test should be skipped
    /// - Parameter testName: The full test name (ClassName.methodName)
    /// - Returns: True if the test should be skipped
    public static func shouldSkip(_ testName: String) -> Bool {
        if case .skip = quarantinedTests[testName] ?? .expectedToFail {
            return true
        }
        return false
    }
    
    /// Handles a test failure based on its quarantine status
    /// - Parameters:
    ///   - testCase: The XCTestCase instance
    ///   - error: The error that occurred
    ///   - file: The file where the failure occurred
    ///   - line: The line where the failure occurred
    /// - Returns: True if the failure was handled (test is quarantined), false otherwise
    @discardableResult
    public static func handleFailure(
        in testCase: XCTestCase,
        error: Error,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let testName = "\(type(of: testCase)).\(testCase.name)"
        
        guard let status = statusForTest(testName) else {
            // Test is not quarantined, let the failure propagate
            return false
        }
        
        switch status {
        case .expectedToFail:
            // Just log the expected failure without failing the test
            XCTContext.runActivity(named: "Expected Failure") { _ in
                let message = "Test '\(testName)' is expected to fail: \(error.localizedDescription)"
                XCTFail(message, file: file, line: line)
            }
            return true
            
        case .flaky(let reason):
            // Log the flaky test failure and allow it to pass
            XCTContext.runActivity(named: "Flaky Test") { _ in
                let message = "Test '\(testName)' is marked as flaky (\(reason)): \(error.localizedDescription)"
                XCTFail(message, file: file, line: line)
            }
            return true
            
        case .skip:
            // This shouldn't happen since skipped tests shouldn't run at all
            return false
        }
    }
}

/// Extension to XCTestCase to make it easier to work with quarantined tests
public extension XCTestCase {
    
    /// Check if the current test is quarantined and should be skipped or handled specially
    func checkQuarantine() {
        let testName = "\(type(of: self)).\(name)"
        if TestQuarantine.shouldSkip(testName) {
            if case .skip(let reason)? = TestQuarantine.statusForTest(testName) {
                XCTContext.runActivity(named: "Skipped Test") { _ in
                    XCTFail("Test '\(testName)' is skipped: \(reason)")
                }
                throw XCTSkip("Test is quarantined: \(reason)")
            }
        }
    }
    
    /// Run potentially flaky code and handle failures if the test is quarantined
    func quarantineRunning(_ block: () throws -> Void) {
        do {
            try block()
        } catch {
            if !TestQuarantine.handleFailure(in: self, error: error) {
                // If the test is not quarantined or the error wasn't handled, rethrow
                throw error
            }
        }
    }
    
    /// Generate a report of all quarantined tests in the suite
    static func generateQuarantineReport() -> String {
        var report = "# Test Quarantine Report\n\n"
        report += "Last generated: \(Date())\n\n"
        report += "| Test | Status | Reason |\n"
        report += "|------|--------|--------|\n"
        
        let allTests = TestQuarantine.allQuarantinedTests.sorted()
        for testName in allTests {
            guard let status = TestQuarantine.statusForTest(testName) else { continue }
            
            switch status {
            case .expectedToFail:
                report += "| \(testName) | Expected to Fail | - |\n"
            case .flaky(let reason):
                report += "| \(testName) | Flaky | \(reason) |\n"
            case .skip(let reason):
                report += "| \(testName) | Skipped | \(reason) |\n"
            }
        }
        
        return report
    }
}

/// Example usage in a test class:
///
/// ```
/// func testExample() throws {
///     try checkQuarantine() // Will skip if the test is quarantined
///
///     // Option 1: Use quarantineRunning for potentially flaky code
///     quarantineRunning {
///         // Your potentially flaky test code
///     }
///
///     // Option 2: Use try-catch and explicitly handle failure
///     do {
///         // Your test code
///     } catch {
///         if !TestQuarantine.handleFailure(in: self, error: error) {
///             throw error // Re-throw if not handled by quarantine
///         }
///     }
/// }
/// ```

/// A property wrapper that marks a test as quarantined.
/// This allows tracking and management of flaky tests.
///
/// Usage:
/// ```swift
/// @TestQuarantine(reason: "Network timeout", ticketID: "HDR-123", failureRate: 0.2)
/// func testFlaky() {
///    // Test implementation
/// }
/// ```
@propertyWrapper
public struct TestQuarantine<T> {
    private let reason: String
    private let ticketID: String?
    private let failureRate: Double?
    private let skipInCI: Bool
    private let skipOnPlatforms: [String]
    private let wrappedValue: T
    private let createdAt: Date
    
    /// Initialize a test quarantine
    /// - Parameters:
    ///   - wrappedValue: The test function
    ///   - reason: Reason why the test is quarantined
    ///   - ticketID: Issue/ticket ID tracking the problem
    ///   - failureRate: Approximate failure rate (0.0-1.0)
    ///   - skipInCI: Whether to skip the test in CI environments
    ///   - skipOnPlatforms: Platforms to skip the test on
    public init(
        wrappedValue: T,
        reason: String,
        ticketID: String? = nil,
        failureRate: Double? = nil,
        skipInCI: Bool = true,
        skipOnPlatforms: [String] = []
    ) {
        self.wrappedValue = wrappedValue
        self.reason = reason
        self.ticketID = ticketID
        self.failureRate = failureRate
        self.skipInCI = skipInCI
        self.skipOnPlatforms = skipOnPlatforms
        self.createdAt = Date()
    }
    
    public var projectedValue: TestQuarantineInfo {
        return TestQuarantineInfo(
            reason: reason,
            ticketID: ticketID,
            failureRate: failureRate,
            skipInCI: skipInCI,
            skipOnPlatforms: skipOnPlatforms,
            createdAt: createdAt
        )
    }
}

/// Information about a quarantined test
public struct TestQuarantineInfo {
    public let reason: String
    public let ticketID: String?
    public let failureRate: Double?
    public let skipInCI: Bool
    public let skipOnPlatforms: [String]
    public let createdAt: Date
    
    /// Returns true if the test should be skipped in the current environment
    public var shouldSkip: Bool {
        if skipInCI && QuarantineManager.shared.isCI {
            return true
        }
        
        #if os(macOS)
        if skipOnPlatforms.contains("macOS") {
            return true
        }
        #elseif os(iOS)
        if skipOnPlatforms.contains("iOS") {
            return true
        }
        #endif
        
        return false
    }
}

/// Manages test quarantine data
public class QuarantineManager {
    /// Shared instance
    public static let shared = QuarantineManager()
    
    /// Whether we're running in a CI environment
    public var isCI: Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil ||
               ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }
    
    /// Database of quarantined tests
    private var quarantinedTests: [String: TestQuarantineInfo] = [:]
    
    /// Get data for a quarantined test
    public func getInfo(for testName: String) -> TestQuarantineInfo? {
        return quarantinedTests[testName]
    }
    
    /// Register a test in quarantine
    public func register(testName: String, info: TestQuarantineInfo) {
        quarantinedTests[testName] = info
        
        if TestOutputFormatter.shared.options.verbosityLevel > 0 {
            let ticket = info.ticketID != nil ? " (\(info.ticketID!))" : ""
            let failureRate = info.failureRate != nil ? " Failure rate: \(Int(info.failureRate! * 100))%" : ""
            
            print("⚠️ Quarantined test: \(testName)\(ticket)")
            print("   Reason: \(info.reason)\(failureRate)")
            
            if info.shouldSkip {
                print("   Test will be skipped")
            } else {
                print("   Test will be run but failures won't affect CI")
            }
        }
    }
    
    /// Export quarantine data as JSON
    public func exportJSON() -> Data? {
        var exportData: [String: [String: Any]] = [:]
        
        for (testName, info) in quarantinedTests {
            var infoDict: [String: Any] = [
                "reason": info.reason,
                "skipInCI": info.skipInCI,
                "created": ISO8601DateFormatter().string(from: info.createdAt)
            ]
            
            if let ticketID = info.ticketID {
                infoDict["ticketID"] = ticketID
            }
            
            if let failureRate = info.failureRate {
                infoDict["failureRate"] = failureRate
            }
            
            if !info.skipOnPlatforms.isEmpty {
                infoDict["skipOnPlatforms"] = info.skipOnPlatforms
            }
            
            exportData[testName] = infoDict
        }
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted])
    }
    
    /// Load quarantine database from JSON
    public func loadFromJSON(data: Data) throws {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: Any]] else {
            throw NSError(domain: "QuarantineManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid quarantine JSON format"])
        }
        
        for (testName, infoDict) in jsonObject {
            guard let reason = infoDict["reason"] as? String else { continue }
            
            let ticketID = infoDict["ticketID"] as? String
            let failureRate = infoDict["failureRate"] as? Double
            let skipInCI = infoDict["skipInCI"] as? Bool ?? true
            let skipOnPlatforms = infoDict["skipOnPlatforms"] as? [String] ?? []
            
            let createdAt: Date
            if let dateString = infoDict["created"] as? String,
               let date = ISO8601DateFormatter().date(from: dateString) {
                createdAt = date
            } else {
                createdAt = Date()
            }
            
            let info = TestQuarantineInfo(
                reason: reason,
                ticketID: ticketID,
                failureRate: failureRate,
                skipInCI: skipInCI,
                skipOnPlatforms: skipOnPlatforms,
                createdAt: createdAt
            )
            
            quarantinedTests[testName] = info
        }
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Check if the current test is quarantined and should be skipped
    public func checkQuarantine() throws {
        // Get the current test name
        let testName = String(reflecting: type(of: self)) + "." + name
        
        // Find property wrappers in the test class
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let propertyName = child.label,
               propertyName.hasPrefix("$"),
               let quarantineInfo = child.value as? TestQuarantineInfo {
                
                // Register the test in the quarantine manager
                let fullTestName = String(reflecting: type(of: self)) + "." + propertyName.dropFirst()
                QuarantineManager.shared.register(testName: fullTestName, info: quarantineInfo)
                
                // If this is the current test and it should be skipped, throw XCTSkip
                if fullTestName == testName && quarantineInfo.shouldSkip {
                    let ticketReference = quarantineInfo.ticketID != nil ? " (Ticket: \(quarantineInfo.ticketID!))" : ""
                    throw XCTSkip("Test is quarantined: \(quarantineInfo.reason)\(ticketReference)")
                }
            }
        }
    }
} 