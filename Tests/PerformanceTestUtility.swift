import Foundation
import XCTest

/// A utility for measuring and tracking performance of HDR+ operations.
/// This class provides methods for measuring execution time and memory usage,
/// comparing against baselines, and recording performance history.
public final class PerformanceTestUtility {
    
    // MARK: - Types
    
    /// A performance metric type
    public enum MetricType {
        case executionTime
        case memoryUsage
        
        var displayName: String {
            switch self {
            case .executionTime: return "Execution Time"
            case .memoryUsage: return "Memory Usage"
            }
        }
        
        var unit: String {
            switch self {
            case .executionTime: return "ms"
            case .memoryUsage: return "MB"
            }
        }
    }
    
    /// A performance metric with baseline comparison
    public struct PerformanceMetric {
        /// The name of the performance test
        public let name: String
        
        /// The metric type (execution time or memory usage)
        public let type: MetricType
        
        /// The measured value
        public let value: Double
        
        /// The baseline value to compare against
        public let baseline: Double
        
        /// The acceptable deviation as a percentage (0.2 = 20%)
        public let acceptableDeviation: Double
        
        /// The change relative to baseline as a percentage
        public var change: Double {
            return (value - baseline) / baseline
        }
        
        /// Whether the performance is acceptable (within deviation)
        public var isAcceptable: Bool {
            return abs(change) <= acceptableDeviation
        }
        
        /// A description of the performance trend
        public var trend: String {
            if abs(change) <= 0.05 {
                return "Stable"
            } else if value < baseline {
                return "Improved"
            } else {
                return "Degraded"
            }
        }
        
        /// The timestamp when this metric was recorded
        public let timestamp: Date
        
        /// Initialize a new performance metric
        public init(name: String, type: MetricType, value: Double, baseline: Double, acceptableDeviation: Double, timestamp: Date = Date()) {
            self.name = name
            self.type = type
            self.value = value
            self.baseline = baseline
            self.acceptableDeviation = acceptableDeviation
            self.timestamp = timestamp
        }
    }
    
    /// A performance test history record
    public struct PerformanceHistory: Codable {
        /// The name of the performance test
        public let name: String
        
        /// The metric type
        public let type: String
        
        /// Historical measurements
        public var measurements: [Measurement]
        
        /// A single measurement in the history
        public struct Measurement: Codable {
            /// The measured value
            public let value: Double
            
            /// The baseline at the time of measurement
            public let baseline: Double
            
            /// The timestamp of the measurement
            public let timestamp: Date
            
            /// The device information
            public let device: String
            
            /// Initialize a new measurement
            public init(value: Double, baseline: Double, timestamp: Date = Date(), device: String = PerformanceTestUtility.deviceIdentifier) {
                self.value = value
                self.baseline = baseline
                self.timestamp = timestamp
                self.device = device
            }
        }
        
        /// Initialize a new performance history
        public init(name: String, type: MetricType, initialMeasurement: Measurement? = nil) {
            self.name = name
            self.type = type.displayName
            self.measurements = initialMeasurement.map { [$0] } ?? []
        }
        
        /// Add a new measurement to the history
        public mutating func addMeasurement(value: Double, baseline: Double) {
            let measurement = Measurement(value: value, baseline: baseline)
            measurements.append(measurement)
            
            // Keep only the most recent 100 measurements
            if measurements.count > 100 {
                measurements.removeFirst(measurements.count - 100)
            }
        }
    }
    
    // MARK: - Static Properties
    
    /// A string identifying the current device
    public static let deviceIdentifier: String = {
        let deviceName = ProcessInfo.processInfo.hostName
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(deviceName) (\(osVersion))"
    }()
    
    /// Default acceptable deviation (20% by default)
    public static let defaultAcceptableDeviation = 0.2
    
    // MARK: - Instance Properties
    
    /// The test case that owns this utility
    private weak var testCase: XCTestCase?
    
    /// Directory for storing performance baselines
    private let baselineDir: URL
    
    /// Directory for storing performance history
    private let historyDir: URL
    
    /// Whether to save performance history
    public var saveHistory: Bool
    
    /// Whether to update baselines automatically when they don't exist
    public var updateBaselinesAutomatically: Bool
    
    /// Whether to fail tests when performance doesn't meet baseline
    public var failTestsOnPerformanceIssues: Bool
    
    // MARK: - Initialization
    
    /// Initialize a new performance test utility
    /// - Parameters:
    ///   - testCase: The test case that owns this utility
    ///   - saveHistory: Whether to save performance history
    ///   - updateBaselinesAutomatically: Whether to update baselines automatically
    ///   - failTestsOnPerformanceIssues: Whether to fail tests on performance issues
    public init(testCase: XCTestCase, saveHistory: Bool = true, updateBaselinesAutomatically: Bool = true, failTestsOnPerformanceIssues: Bool = true) {
        self.testCase = testCase
        self.baselineDir = TestConfig.shared.performanceBaselinesDir
        self.historyDir = TestConfig.shared.testResourcesDir.appendingPathComponent("PerformanceHistory")
        self.saveHistory = saveHistory
        self.updateBaselinesAutomatically = updateBaselinesAutomatically
        self.failTestsOnPerformanceIssues = failTestsOnPerformanceIssues
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: baselineDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Measure the execution time of a block of code.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - baselineValue: The expected execution time in milliseconds
    ///   - acceptableDeviation: The acceptable deviation as a percentage (0.2 = 20%)
    ///   - block: The block of code to measure
    /// - Returns: The measured performance metric
    @discardableResult
    public func measureExecutionTime(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double = PerformanceTestUtility.defaultAcceptableDeviation,
        block: () throws -> Void
    ) rethrows -> PerformanceMetric {
        // Get baseline value from file or parameter
        let baseline = baselineValue ?? getBaseline(for: name, type: .executionTime, defaultValue: 1000.0)
        
        // Measure execution time
        let startTime = CFAbsoluteTimeGetCurrent()
        try block()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Calculate execution time in milliseconds
        let executionTime = (endTime - startTime) * 1000.0
        
        // Create and record metric
        let metric = PerformanceMetric(
            name: name,
            type: .executionTime,
            value: executionTime,
            baseline: baseline,
            acceptableDeviation: acceptableDeviation
        )
        
        // Record the metric
        recordPerformanceMetric(metric)
        
        return metric
    }
    
    /// Measure the memory usage of a block of code.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - baselineValue: The expected memory usage in megabytes
    ///   - acceptableDeviation: The acceptable deviation as a percentage (0.2 = 20%)
    ///   - block: The block of code to measure
    /// - Returns: The measured performance metric
    @discardableResult
    public func measureMemoryUsage(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double = PerformanceTestUtility.defaultAcceptableDeviation,
        block: () throws -> Void
    ) rethrows -> PerformanceMetric {
        // Get baseline value from file or parameter
        let baseline = baselineValue ?? getMemoryBaseline(for: name, defaultValue: 100.0)
        
        // Get initial memory usage
        let initialMemory = currentMemoryUsageMB()
        
        // Execute the block
        try block()
        
        // Get final memory usage
        let finalMemory = currentMemoryUsageMB()
        
        // Calculate memory difference in MB
        let memoryUsage = max(0, finalMemory - initialMemory)
        
        // Create and record metric
        let metric = PerformanceMetric(
            name: name,
            type: .memoryUsage,
            value: memoryUsage,
            baseline: baseline,
            acceptableDeviation: acceptableDeviation
        )
        
        // Record the metric
        recordPerformanceMetric(metric)
        
        return metric
    }
    
    // MARK: - Private Methods
    
    /// Record a performance metric and optionally update baseline and history.
    /// - Parameter metric: The performance metric to record
    private func recordPerformanceMetric(_ metric: PerformanceMetric) {
        // Log the metric
        TestConfig.shared.logVerbose("Performance: \(metric.name) (\(metric.type.displayName))")
        TestConfig.shared.logVerbose("  Value: \(String(format: "%.2f", metric.value)) \(metric.type.unit)")
        TestConfig.shared.logVerbose("  Baseline: \(String(format: "%.2f", metric.baseline)) \(metric.type.unit)")
        TestConfig.shared.logVerbose("  Change: \(String(format: "%.1f", metric.change * 100))%")
        TestConfig.shared.logVerbose("  Trend: \(metric.trend)")
        TestConfig.shared.logVerbose("  Acceptable: \(metric.isAcceptable ? "Yes" : "No")")
        
        // Update baseline if needed and authorized
        if updateBaselinesAutomatically && !metric.isAcceptable {
            TestConfig.shared.logVerbose("  Updating baseline to \(String(format: "%.2f", metric.value)) \(metric.type.unit)")
            updateBaseline(for: metric.name, type: metric.type, value: metric.value)
        }
        
        // Save to history if enabled
        if saveHistory {
            saveMetricToHistory(metric)
        }
        
        // Fail the test if needed
        if failTestsOnPerformanceIssues && !metric.isAcceptable {
            testCase?.continueAfterFailure = true
            testCase?.recordFailure(
                withDescription: """
                    Performance issue detected: \(metric.name) (\(metric.type.displayName))
                    Value: \(String(format: "%.2f", metric.value)) \(metric.type.unit)
                    Baseline: \(String(format: "%.2f", metric.baseline)) \(metric.type.unit)
                    Change: \(String(format: "%.1f", metric.change * 100))%
                    Acceptable deviation: \(String(format: "%.1f", metric.acceptableDeviation * 100))%
                    """,
                inFile: #file,
                atLine: #line,
                expected: true
            )
        }
    }
    
    /// Get the baseline value for an execution time test.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - type: The metric type
    ///   - defaultValue: The default value to use if no baseline is found
    /// - Returns: The baseline value
    private func getBaseline(for name: String, type: MetricType, defaultValue: Double) -> Double {
        let fileURL = baselineFileURL(for: name, type: type)
        
        guard let data = try? Data(contentsOf: fileURL),
              let baseline = Double(String(data: data, encoding: .utf8) ?? "") else {
            // No baseline found, use default
            return defaultValue
        }
        
        return baseline
    }
    
    /// Get the baseline value for a memory usage test.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - defaultValue: The default value to use if no baseline is found
    /// - Returns: The baseline memory usage in megabytes
    private func getMemoryBaseline(for name: String, defaultValue: Double) -> Double {
        return getBaseline(for: name, type: .memoryUsage, defaultValue: defaultValue)
    }
    
    /// Update the baseline value for a performance test.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - type: The metric type
    ///   - value: The new baseline value
    private func updateBaseline(for name: String, type: MetricType, value: Double) {
        let fileURL = baselineFileURL(for: name, type: type)
        let directory = fileURL.deletingLastPathComponent()
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            // Write baseline to file
            let stringValue = String(format: "%.2f", value)
            try stringValue.data(using: .utf8)?.write(to: fileURL)
            
            TestConfig.shared.logVerbose("Updated baseline for \(name) (\(type.displayName)) to \(stringValue)")
        } catch {
            TestConfig.shared.logVerbose("Failed to update baseline: \(error)")
        }
    }
    
    /// Save a performance metric to the history.
    /// - Parameter metric: The performance metric to save
    private func saveMetricToHistory(_ metric: PerformanceMetric) {
        let fileURL = historyFileURL(for: metric.name, type: metric.type)
        
        do {
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            // Read existing history or create new one
            var history: PerformanceHistory
            
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? JSONDecoder().decode(PerformanceHistory.self, from: data) {
                history = decoded
            } else {
                history = PerformanceHistory(name: metric.name, type: metric.type)
            }
            
            // Add the new measurement
            history.addMeasurement(value: metric.value, baseline: metric.baseline)
            
            // Save the updated history
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: fileURL)
            
            TestConfig.shared.logVerbose("Saved performance history for \(metric.name)")
        } catch {
            TestConfig.shared.logVerbose("Failed to save performance history: \(error)")
        }
    }
    
    /// Get the URL for the baseline file.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - type: The metric type
    /// - Returns: The URL for the baseline file
    private func baselineFileURL(for name: String, type: MetricType) -> URL {
        let testClass = String(describing: type(of: testCase!))
        let sanitizedName = name.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(sanitizedName)_\(type.displayName.replacingOccurrences(of: " ", with: "_")).baseline"
        
        return baselineDir
            .appendingPathComponent(testClass)
            .appendingPathComponent(fileName)
    }
    
    /// Get the URL for the history file.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - type: The metric type
    /// - Returns: The URL for the history file
    private func historyFileURL(for name: String, type: MetricType) -> URL {
        let testClass = String(describing: type(of: testCase!))
        let sanitizedName = name.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(sanitizedName)_\(type.displayName.replacingOccurrences(of: " ", with: "_")).json"
        
        return historyDir
            .appendingPathComponent(testClass)
            .appendingPathComponent(fileName)
    }
    
    /// Get the current memory usage in megabytes.
    /// - Returns: The current memory usage in megabytes
    private func currentMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        } else {
            return 0
        }
    }
    
    /// Simulate a measured value for testing purposes.
    /// This is helpful for testing the performance measurement infrastructure without specific operations.
    /// - Parameters:
    ///   - baseline: The baseline value
    ///   - deviationPercentage: The deviation from baseline as a percentage (-20 to +20)
    /// - Returns: A simulated measured value
    public static func simulateMeasuredValue(baseline: Double, deviationPercentage: Double) -> Double {
        // Clamp deviation to -20% to +20%
        let clampedDeviation = max(-20, min(20, deviationPercentage))
        
        // Calculate value with deviation
        return baseline * (1 + clampedDeviation / 100.0)
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Measure the execution time of a block of code.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - baselineValue: The expected execution time in milliseconds
    ///   - acceptableDeviation: The acceptable deviation as a percentage (0.2 = 20%)
    ///   - block: The block of code to measure
    /// - Returns: The measured performance metric
    @discardableResult
    public func measureExecutionTime(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double = PerformanceTestUtility.defaultAcceptableDeviation,
        block: () throws -> Void
    ) rethrows -> PerformanceTestUtility.PerformanceMetric {
        let utility = PerformanceTestUtility(testCase: self)
        return try utility.measureExecutionTime(
            name: name,
            baselineValue: baselineValue,
            acceptableDeviation: acceptableDeviation,
            block: block
        )
    }
    
    /// Measure the memory usage of a block of code.
    /// - Parameters:
    ///   - name: The name of the performance test
    ///   - baselineValue: The expected memory usage in megabytes
    ///   - acceptableDeviation: The acceptable deviation as a percentage (0.2 = 20%)
    ///   - block: The block of code to measure
    /// - Returns: The measured performance metric
    @discardableResult
    public func measureMemoryUsage(
        name: String,
        baselineValue: Double? = nil,
        acceptableDeviation: Double = PerformanceTestUtility.defaultAcceptableDeviation,
        block: () throws -> Void
    ) rethrows -> PerformanceTestUtility.PerformanceMetric {
        let utility = PerformanceTestUtility(testCase: self)
        return try utility.measureMemoryUsage(
            name: name,
            baselineValue: baselineValue,
            acceptableDeviation: acceptableDeviation,
            block: block
        )
    }
} 