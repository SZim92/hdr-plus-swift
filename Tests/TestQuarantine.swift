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