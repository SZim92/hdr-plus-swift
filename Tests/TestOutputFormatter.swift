import Foundation
import XCTest

/// A utility for formatting and visualizing test output.
/// This class provides methods to format test results, generate reports, and visualize data.
public class TestOutputFormatter {
    
    /// Singleton instance
    public static let shared = TestOutputFormatter()
    
    /// Formatting options for test output
    public struct FormattingOptions {
        /// Whether to include timestamp in output
        public var includeTimestamp: Bool = true
        /// Whether to include emoji indicators
        public var includeEmoji: Bool = true
        /// Whether to use color in console output
        public var useColor: Bool = true
        /// Verbosity level (0-3)
        public var verbosityLevel: Int = 1
        
        /// Preset for minimal output
        public static let minimal = FormattingOptions(includeTimestamp: false, includeEmoji: false, useColor: false, verbosityLevel: 0)
        /// Preset for normal output
        public static let normal = FormattingOptions(includeTimestamp: true, includeEmoji: true, useColor: true, verbosityLevel: 1)
        /// Preset for verbose output
        public static let verbose = FormattingOptions(includeTimestamp: true, includeEmoji: true, useColor: true, verbosityLevel: 2)
        /// Preset for debug output
        public static let debug = FormattingOptions(includeTimestamp: true, includeEmoji: true, useColor: true, verbosityLevel: 3)
    }
    
    /// Current formatting options
    public var options: FormattingOptions = .normal
    
    /// Output file handle (defaults to standard output)
    private var outputHandle: FileHandle = .standardOutput
    
    /// Initialize with custom options
    public init(options: FormattingOptions = .normal) {
        self.options = options
    }
    
    /// ANSI color codes
    private enum ANSIColor: String {
        case reset = "\u{001B}[0m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case gray = "\u{001B}[37m"
        case boldRed = "\u{001B}[1;31m"
        case boldGreen = "\u{001B}[1;32m"
        case boldYellow = "\u{001B}[1;33m"
        case boldBlue = "\u{001B}[1;34m"
    }
    
    /// Emoji indicators
    private enum StatusEmoji: String {
        case success = "✅"
        case failure = "❌"
        case warning = "⚠️"
        case info = "ℹ️"
        case skip = "⏭️"
        case start = "🚀"
        case end = "🏁"
        case debug = "🔍"
    }
    
    // MARK: - Formatting Methods
    
    /// Format message with optional emoji, timestamp, and color
    private func format(message: String, emoji: StatusEmoji? = nil, color: ANSIColor? = nil) -> String {
        var formattedMessage = ""
        
        // Add timestamp if enabled
        if options.includeTimestamp {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss.SSS"
            formattedMessage += "[\(dateFormatter.string(from: Date()))] "
        }
        
        // Add emoji if enabled
        if options.includeEmoji, let emoji = emoji {
            formattedMessage += "\(emoji.rawValue) "
        }
        
        // Add color if enabled
        if options.useColor, let color = color {
            formattedMessage += "\(color.rawValue)\(message)\(ANSIColor.reset.rawValue)"
        } else {
            formattedMessage += message
        }
        
        return formattedMessage
    }
    
    /// Log a message to the output
    private func log(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }
        outputHandle.write(data)
    }
    
    // MARK: - Public Logging Methods
    
    /// Log a success message
    public func logSuccess(_ message: String) {
        log(format(message: message, emoji: .success, color: .green))
    }
    
    /// Log an error message
    public func logError(_ message: String) {
        log(format(message: message, emoji: .failure, color: .red))
    }
    
    /// Log a warning message
    public func logWarning(_ message: String) {
        log(format(message: message, emoji: .warning, color: .yellow))
    }
    
    /// Log an informational message
    public func logInfo(_ message: String) {
        log(format(message: message, emoji: .info, color: .blue))
    }
    
    /// Log a debug message (only shown at verbosity level 2+)
    public func logDebug(_ message: String) {
        if options.verbosityLevel >= 2 {
            log(format(message: message, emoji: .debug, color: .gray))
        }
    }
    
    /// Log a test skipped message
    public func logSkipped(_ testName: String, reason: String) {
        log(format(message: "SKIPPED: \(testName) - \(reason)", emoji: .skip, color: .cyan))
    }
    
    /// Log the start of a test or test suite
    public func logTestStart(_ name: String) {
        log(format(message: "STARTED: \(name)", emoji: .start, color: .blue))
    }
    
    /// Log the end of a test or test suite
    public func logTestEnd(_ name: String, duration: TimeInterval, passed: Bool) {
        let status = passed ? "PASSED" : "FAILED"
        let color: ANSIColor = passed ? .green : .red
        let emoji: StatusEmoji = passed ? .success : .failure
        log(format(message: "\(status): \(name) (\(String(format: "%.3f", duration))s)", emoji: emoji, color: color))
    }
    
    // MARK: - Test Summary Methods
    
    /// Generate a test summary string
    public func generateTestSummary(total: Int, passed: Int, failed: Int, skipped: Int, duration: TimeInterval) -> String {
        let summaryLines = [
            "TEST SUMMARY:",
            "Total: \(total)",
            "Passed: \(passed)",
            "Failed: \(failed)",
            "Skipped: \(skipped)",
            "Duration: \(String(format: "%.3f", duration)) seconds"
        ]
        
        let result = summaryLines.joined(separator: "\n")
        
        let color: ANSIColor = failed > 0 ? .red : .green
        return format(message: result, color: color)
    }
    
    /// Format test result for XCTest output
    public func formatTestResult(_ result: XCTResult) -> String {
        switch result.status {
        case .success:
            return format(message: "PASSED", emoji: .success, color: .green)
        case .failure:
            var message = "FAILED"
            if let failureMessage = result.failureMessage {
                message += " - \(failureMessage)"
            }
            return format(message: message, emoji: .failure, color: .red)
        }
    }
    
    // MARK: - Visualization Methods
    
    /// Generate ASCII progress bar
    public func generateProgressBar(progress: Double, width: Int = 40) -> String {
        let clampedProgress = min(1.0, max(0.0, progress))
        let filledWidth = Int(Double(width) * clampedProgress)
        let emptyWidth = width - filledWidth
        
        let filled = String(repeating: "█", count: filledWidth)
        let empty = String(repeating: "░", count: emptyWidth)
        let percentage = String(format: "%3.0f%%", clampedProgress * 100)
        
        var color: ANSIColor = .blue
        if clampedProgress >= 1.0 {
            color = .green
        } else if clampedProgress >= 0.6 {
            color = .blue
        } else if clampedProgress >= 0.3 {
            color = .yellow
        } else {
            color = .red
        }
        
        return options.useColor ? 
            "\(color.rawValue)[\(filled)\(empty)] \(percentage)\(ANSIColor.reset.rawValue)" :
            "[\(filled)\(empty)] \(percentage)"
    }
    
    /// Generate a simple ASCII histogram for test durations
    public func generateHistogram(data: [String: TimeInterval], maxBarLength: Int = 40) -> String {
        guard !data.isEmpty else { return "No data to display" }
        
        let sortedData = data.sorted { $0.value > $1.value }
        let maxValue = sortedData.first!.value
        
        var result = "Test Duration Histogram:\n"
        
        for (name, value) in sortedData {
            let barLength = Int((value / maxValue) * Double(maxBarLength))
            let bar = String(repeating: "█", count: barLength)
            let formattedValue = String(format: "%.3fs", value)
            result += "\(name.padding(toLength: 30, withPad: " ", startingAt: 0)) | \(formattedValue.padding(toLength: 8, withPad: " ", startingAt: 0)) | \(bar)\n"
        }
        
        return result
    }
    
    /// Generate a simple report for performance test results
    public func generatePerformanceReport(results: [String: [String: Double]]) -> String {
        var report = "PERFORMANCE TEST REPORT:\n"
        
        // For each test class
        for (className, metrics) in results.sorted(by: { $0.key < $1.key }) {
            report += "\n== \(className) ==\n"
            
            // For each metric in the class
            for (metricName, value) in metrics.sorted(by: { $0.key < $1.key }) {
                let formattedValue: String
                
                // Format the value appropriately based on the metric name
                if metricName.contains("time") || metricName.contains("duration") {
                    formattedValue = String(format: "%.3f seconds", value)
                } else if metricName.contains("memory") {
                    formattedValue = String(format: "%.2f MB", value)
                } else if metricName.contains("count") {
                    formattedValue = String(format: "%.0f", value)
                } else {
                    formattedValue = String(format: "%.3f", value)
                }
                
                report += "\(metricName.padding(toLength: 30, withPad: " ", startingAt: 0)): \(formattedValue)\n"
            }
        }
        
        return report
    }
    
    // MARK: - Output Methods
    
    /// Redirect output to a file
    public func redirectOutput(to fileURL: URL) throws {
        let fileManager = FileManager.default
        
        // Create directory if needed
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), 
                                      withIntermediateDirectories: true)
        
        // Create the file if it doesn't exist
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
        
        // Open the file for writing
        outputHandle = try FileHandle(forWritingTo: fileURL)
        
        // Clear the file
        outputHandle.truncateFile(atOffset: 0)
    }
    
    /// Reset output to standard output
    public func resetOutput() {
        if outputHandle != .standardOutput {
            outputHandle.closeFile()
            outputHandle = .standardOutput
        }
    }
    
    /// Write test results to an HTML report
    public func writeHTMLReport(testResults: [String: XCTResult], 
                               duration: TimeInterval,
                               outputFile: URL) throws {
        let passed = testResults.filter { $0.value.status == .success }.count
        let failed = testResults.count - passed
        
        // Generate HTML content
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>HDR+ Swift Test Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 20px; line-height: 1.6; }
                h1 { color: #333; }
                .summary { background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
                .test-list { border-collapse: collapse; width: 100%; }
                .test-list th, .test-list td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
                .test-list th { background-color: #f2f2f2; }
                .success { color: green; }
                .failure { color: red; }
                .details { font-family: monospace; white-space: pre-wrap; background-color: #f8f8f8; padding: 10px; border-radius: 3px; margin-top: 5px; }
            </style>
        </head>
        <body>
            <h1>HDR+ Swift Test Report</h1>
            <div class="summary">
                <h2>Summary</h2>
                <p>Total Tests: \(testResults.count)</p>
                <p>Passed: <span class="success">\(passed)</span></p>
                <p>Failed: <span class="failure">\(failed)</span></p>
                <p>Duration: \(String(format: "%.3f", duration)) seconds</p>
                <p>Generated: \(Date())</p>
            </div>
            <h2>Test Results</h2>
            <table class="test-list">
                <tr>
                    <th>Test</th>
                    <th>Status</th>
                    <th>Duration</th>
                </tr>
        """
        
        // Add rows for each test
        for (testName, result) in testResults.sorted(by: { $0.key < $1.key }) {
            let statusClass = result.status == .success ? "success" : "failure"
            let statusText = result.status == .success ? "Passed" : "Failed"
            
            html += """
                <tr>
                    <td>\(testName)</td>
                    <td class="\(statusClass)">\(statusText)</td>
                    <td>\(String(format: "%.3f", result.duration)) s</td>
                </tr>
            """
            
            // Add failure details if applicable
            if result.status == .failure, let failureMessage = result.failureMessage {
                html += """
                <tr>
                    <td colspan="3" class="details">\(failureMessage)</td>
                </tr>
                """
            }
        }
        
        html += """
            </table>
        </body>
        </html>
        """
        
        // Write to file
        try html.write(to: outputFile, atomically: true, encoding: .utf8)
    }
}

// MARK: - XCTResult Structure

/// Represents the result of an XCTest
public struct XCTResult {
    /// Status of the test
    public enum Status {
        case success
        case failure
    }
    
    /// Name of the test
    public let testName: String
    /// Status of the test
    public let status: Status
    /// Duration of the test in seconds
    public let duration: TimeInterval
    /// Failure message if the test failed
    public let failureMessage: String?
    
    /// Create a success result
    public static func success(testName: String, duration: TimeInterval) -> XCTResult {
        return XCTResult(testName: testName, status: .success, duration: duration, failureMessage: nil)
    }
    
    /// Create a failure result
    public static func failure(testName: String, duration: TimeInterval, message: String) -> XCTResult {
        return XCTResult(testName: testName, status: .failure, duration: duration, failureMessage: message)
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Log a message to the test output formatter
    public func log(_ message: String, level: Int = 1) {
        if level <= TestOutputFormatter.shared.options.verbosityLevel {
            TestOutputFormatter.shared.logInfo(message)
        }
    }
    
    /// Log test start
    public func logTestStart() {
        let testName = String(describing: type(of: self)) + "." + name
        TestOutputFormatter.shared.logTestStart(testName)
    }
    
    /// Log test end
    public func logTestEnd(duration: TimeInterval, passed: Bool) {
        let testName = String(describing: type(of: self)) + "." + name
        TestOutputFormatter.shared.logTestEnd(testName, duration: duration, passed: passed)
    }
} 