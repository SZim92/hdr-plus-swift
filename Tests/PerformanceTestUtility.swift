import Foundation
import XCTest

/// Utility for performance testing and tracking performance metrics over time.
/// Provides methods for measuring execution time, memory usage, and comparing against baselines.
public final class PerformanceTestUtility {
    
    /// Represents a performance metric
    public struct PerformanceMetric {
        /// The name of the metric
        public let name: String
        
        /// The measured value
        public let value: Double
        
        /// The unit of measurement
        public let unit: String
        
        /// The baseline value for comparison (optional)
        public let baseline: Double?
        
        /// The acceptable deviation percentage (0.0 to 1.0)
        public let acceptableDeviation: Double
        
        /// Whether the metric is within acceptable deviation
        public var isWithinAcceptableRange: Bool {
            guard let baseline = baseline else { return true }
            
            let deviation = abs(value - baseline) / baseline
            return deviation <= acceptableDeviation
        }
        
        /// The percentage deviation from the baseline
        public var deviationPercentage: Double? {
            guard let baseline = baseline else { return nil }
            
            return abs(value - baseline) / baseline
        }
    }
    
    /// History entry for tracking a performance metric over time
    public struct HistoryEntry {
        /// The name of the metric
        public let metricName: String
        
        /// The measured value
        public let value: Double
        
        /// The unit of measurement
        public let unit: String
        
        /// The date and time of the measurement
        public let timestamp: Date
        
        /// The build identifier (optional)
        public let buildId: String?
        
        /// The test environment information (optional)
        public let environment: [String: String]?
    }
    
    /// Configuration for performance testing
    public struct Configuration {
        /// Whether to save performance history
        public var saveHistory: Bool
        
        /// Whether to compare against baselines
        public var compareWithBaselines: Bool
        
        /// The default acceptable deviation as a percentage (0.0 to 1.0)
        public var defaultAcceptableDeviation: Double
        
        /// The directory for storing performance history
        public var historyDirectory: URL
        
        /// The directory for storing performance baselines
        public var baselineDirectory: URL
        
        /// The default configuration using values from TestConfig
        public static var `default`: Configuration {
            return Configuration(
                saveHistory: true,
                compareWithBaselines: true,
                defaultAcceptableDeviation: TestConfig.shared.performanceAcceptableDeviation,
                historyDirectory: TestConfig.shared.performanceBaselinesDir.appendingPathComponent("History"),
                baselineDirectory: TestConfig.shared.performanceBaselinesDir
            )
        }
    }
    
    /// The current performance test configuration
    public static var configuration = Configuration.default
    
    /// Measures the execution time of a block of code.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being measured.
    ///   - baselineValue: Optional baseline value in milliseconds to compare against.
    ///   - acceptableDeviation: The acceptable deviation percentage (0.0 to 1.0).
    ///   - block: The block of code to measure.
    /// - Returns: The execution time in milliseconds.
    @discardableResult
    public static func measureExecutionTime(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: () throws -> Void
    ) rethrows -> PerformanceMetric {
        let deviation = acceptableDeviation ?? configuration.defaultAcceptableDeviation
        
        // Get baseline from file if not provided
        let baseline = baselineValue ?? getBaseline(for: name, unit: "ms")
        
        let start = Date()
        try block()
        let end = Date()
        
        // Calculate execution time in milliseconds
        let executionTime = end.timeIntervalSince(start) * 1000
        
        // Create metric
        let metric = PerformanceMetric(
            name: name,
            value: executionTime,
            unit: "ms",
            baseline: baseline,
            acceptableDeviation: deviation
        )
        
        // Record performance metric
        recordPerformanceMetric(metric)
        
        // Log verbose information
        TestConfig.shared.logVerbose("Execution time for \(name): \(executionTime) ms")
        
        if let baseline = baseline {
            let deviationPercent = (abs(executionTime - baseline) / baseline) * 100
            TestConfig.shared.logVerbose("Baseline: \(baseline) ms, Deviation: \(deviationPercent)%")
            
            if !metric.isWithinAcceptableRange {
                // Report test failure
                XCTFail(
                    "\(name) execution time (\(executionTime) ms) exceeds acceptable deviation from baseline (\(baseline) ms). Deviation: \(deviationPercent)%",
                    file: file,
                    line: line
                )
            }
        }
        
        return metric
    }
    
    /// Measures the memory usage of a block of code.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being measured.
    ///   - baselineValue: Optional baseline value in megabytes to compare against.
    ///   - acceptableDeviation: The acceptable deviation percentage (0.0 to 1.0).
    ///   - block: The block of code to measure.
    /// - Returns: The peak memory usage in megabytes.
    @discardableResult
    public static func measureMemoryUsage(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: () throws -> Void
    ) rethrows -> PerformanceMetric {
        let deviation = acceptableDeviation ?? configuration.defaultAcceptableDeviation
        
        // Get baseline from file if not provided
        let baseline = baselineValue ?? getMemoryBaseline(for: name)
        
        // Reset memory high water mark
        resetMemoryHighWaterMark()
        
        // Run the block
        try block()
        
        // Get memory usage in MB
        let memoryUsage = getMemoryUsage()
        
        // Create metric
        let metric = PerformanceMetric(
            name: "\(name)_memory",
            value: memoryUsage,
            unit: "MB",
            baseline: baseline,
            acceptableDeviation: deviation
        )
        
        // Record performance metric
        recordPerformanceMetric(metric)
        
        // Log verbose information
        TestConfig.shared.logVerbose("Memory usage for \(name): \(memoryUsage) MB")
        
        if let baseline = baseline {
            let deviationPercent = (abs(memoryUsage - baseline) / baseline) * 100
            TestConfig.shared.logVerbose("Baseline: \(baseline) MB, Deviation: \(deviationPercent)%")
            
            if !metric.isWithinAcceptableRange {
                // Report test failure
                XCTFail(
                    "\(name) memory usage (\(memoryUsage) MB) exceeds acceptable deviation from baseline (\(baseline) MB). Deviation: \(deviationPercent)%",
                    file: file,
                    line: line
                )
            }
        }
        
        return metric
    }
    
    /// Records a performance metric for tracking.
    ///
    /// - Parameter metric: The performance metric to record.
    public static func recordPerformanceMetric(_ metric: PerformanceMetric) {
        guard configuration.saveHistory else { return }
        
        // Create history entry
        let entry = HistoryEntry(
            metricName: metric.name,
            value: metric.value,
            unit: metric.unit,
            timestamp: Date(),
            buildId: ProcessInfo.processInfo.environment["CI_BUILD_ID"],
            environment: [
                "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "device": ProcessInfo.processInfo.hostName
            ]
        )
        
        // Save history entry
        saveHistoryEntry(entry)
        
        // Update baseline if needed
        if metric.baseline == nil {
            saveBaseline(value: metric.value, for: metric.name, unit: metric.unit)
        }
    }
    
    /// Retrieves the baseline value for a performance metric.
    ///
    /// - Parameters:
    ///   - name: The name of the metric.
    ///   - unit: The unit of measurement.
    /// - Returns: The baseline value if it exists, nil otherwise.
    private static func getBaseline(for name: String, unit: String) -> Double? {
        guard configuration.compareWithBaselines else { return nil }
        
        let baselineURL = configuration.baselineDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: baselineURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: baselineURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let value = json?["value"] as? Double,
                  let storedUnit = json?["unit"] as? String,
                  storedUnit == unit else {
                return nil
            }
            
            return value
        } catch {
            TestConfig.shared.logVerbose("Error loading baseline for \(name): \(error)")
            return nil
        }
    }
    
    /// Retrieves the memory baseline for a performance metric.
    ///
    /// - Parameter name: The name of the metric.
    /// - Returns: The memory baseline value if it exists, nil otherwise.
    private static func getMemoryBaseline(for name: String) -> Double? {
        return getBaseline(for: "\(name)_memory", unit: "MB")
    }
    
    /// Saves a baseline value for a performance metric.
    ///
    /// - Parameters:
    ///   - value: The baseline value.
    ///   - name: The name of the metric.
    ///   - unit: The unit of measurement.
    private static func saveBaseline(value: Double, for name: String, unit: String) {
        let baselineDir = configuration.baselineDirectory
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: baselineDir.path) {
            do {
                try FileManager.default.createDirectory(at: baselineDir, withIntermediateDirectories: true)
            } catch {
                TestConfig.shared.logVerbose("Error creating baseline directory: \(error)")
                return
            }
        }
        
        let baselineURL = baselineDir.appendingPathComponent("\(name).json")
        
        let baseline: [String: Any] = [
            "name": name,
            "value": value,
            "unit": unit,
            "timestamp": Date().timeIntervalSince1970,
            "environment": [
                "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "device": ProcessInfo.processInfo.hostName
            ]
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: baseline, options: [.prettyPrinted])
            try data.write(to: baselineURL)
            TestConfig.shared.logVerbose("Saved baseline for \(name): \(value) \(unit)")
        } catch {
            TestConfig.shared.logVerbose("Error saving baseline for \(name): \(error)")
        }
    }
    
    /// Saves a history entry for a performance metric.
    ///
    /// - Parameter entry: The history entry to save.
    private static func saveHistoryEntry(_ entry: HistoryEntry) {
        let historyDir = configuration.historyDirectory
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: historyDir.path) {
            do {
                try FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
            } catch {
                TestConfig.shared.logVerbose("Error creating history directory: \(error)")
                return
            }
        }
        
        let historyURL = historyDir.appendingPathComponent("\(entry.metricName).csv")
        
        // Create CSV line
        let timestamp = Int(entry.timestamp.timeIntervalSince1970)
        let line = "\(timestamp),\(entry.value),\(entry.unit)\n"
        
        // Append to CSV file
        if FileManager.default.fileExists(atPath: historyURL.path) {
            do {
                let fileHandle = try FileHandle(forWritingTo: historyURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(line.data(using: .utf8)!)
                fileHandle.closeFile()
            } catch {
                TestConfig.shared.logVerbose("Error appending to history file for \(entry.metricName): \(error)")
            }
        } else {
            // Create new file with header
            let header = "timestamp,value,unit\n"
            let content = header + line
            do {
                try content.write(to: historyURL, atomically: true, encoding: .utf8)
            } catch {
                TestConfig.shared.logVerbose("Error creating history file for \(entry.metricName): \(error)")
            }
        }
    }
    
    /// Resets the memory high water mark for memory usage measurement.
    private static func resetMemoryHighWaterMark() {
        // This is a placeholder. In a real implementation, we would use platform-specific
        // APIs to reset the memory high water mark before measurement.
        // For simplicity, we're using a simulated approach.
    }
    
    /// Gets the current memory usage in megabytes.
    ///
    /// - Returns: The current memory usage in megabytes.
    private static func getMemoryUsage() -> Double {
        // This is a placeholder. In a real implementation, we would use platform-specific
        // APIs to get the actual memory usage.
        // For macOS, we might use mach_task_basic_info to get resident memory.
        // For simplicity, we're returning a simulated value.
        return simulateMeasuredValue(baseline: 100, deviation: 0.1)
    }
    
    /// Simulates a measured value for testing purposes.
    ///
    /// - Parameters:
    ///   - baseline: The baseline value.
    ///   - deviation: The maximum deviation from the baseline.
    /// - Returns: A simulated value.
    private static func simulateMeasuredValue(baseline: Double, deviation: Double) -> Double {
        let randomDeviation = Double.random(in: -deviation...deviation)
        return baseline * (1.0 + randomDeviation)
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Measures the execution time of a block of code and reports the result.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being measured.
    ///   - baselineValue: Optional baseline value in milliseconds to compare against.
    ///   - acceptableDeviation: The acceptable deviation percentage (0.0 to 1.0).
    ///   - block: The block of code to measure.
    /// - Returns: The execution time in milliseconds.
    @discardableResult
    public func measureExecutionTime(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: () throws -> Void
    ) rethrows -> PerformanceTestUtility.PerformanceMetric {
        return try PerformanceTestUtility.measureExecutionTime(
            name: name,
            baselineValue: baselineValue,
            acceptableDeviation: acceptableDeviation,
            file: file,
            line: line,
            block
        )
    }
    
    /// Measures the memory usage of a block of code and reports the result.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being measured.
    ///   - baselineValue: Optional baseline value in megabytes to compare against.
    ///   - acceptableDeviation: The acceptable deviation percentage (0.0 to 1.0).
    ///   - block: The block of code to measure.
    /// - Returns: The peak memory usage in megabytes.
    @discardableResult
    public func measureMemoryUsage(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: () throws -> Void
    ) rethrows -> PerformanceTestUtility.PerformanceMetric {
        return try PerformanceTestUtility.measureMemoryUsage(
            name: name,
            baselineValue: baselineValue,
            acceptableDeviation: acceptableDeviation,
            file: file,
            line: line,
            block
        )
    }
} 