import Foundation
import XCTest

/// Utility for performance testing and tracking performance metrics over time.
public class PerformanceTestUtility {
    
    // MARK: - Types
    
    /// A performance metric represents a single measurement
    public struct PerformanceMetric: Codable {
        /// The name of the metric
        public let name: String
        
        /// The value of the metric
        public let value: Double
        
        /// The units of the metric
        public let units: String
        
        /// The timestamp of when the metric was recorded
        public let timestamp: Date
        
        /// Any additional metadata for the metric
        public let metadata: [String: String]
        
        /// Create a new performance metric
        /// - Parameters:
        ///   - name: The name of the metric
        ///   - value: The value of the metric
        ///   - units: The units of the metric
        ///   - metadata: Any additional metadata for the metric
        public init(name: String, value: Double, units: String, metadata: [String: String] = [:]) {
            self.name = name
            self.value = value
            self.units = units
            self.timestamp = Date()
            self.metadata = metadata
        }
    }
    
    /// A performance metric history represents the history of a metric over time
    public struct PerformanceMetricHistory: Codable {
        /// The name of the metric
        public let name: String
        
        /// The metrics in the history, ordered by timestamp
        public var metrics: [PerformanceMetric]
        
        /// The baseline value for the metric
        public var baseline: Double?
        
        /// The acceptable deviation from the baseline (as a percentage)
        public var acceptableDeviation: Double?
        
        /// Create a new performance metric history
        /// - Parameters:
        ///   - name: The name of the metric
        ///   - metrics: The metrics in the history
        ///   - baseline: The baseline value for the metric
        ///   - acceptableDeviation: The acceptable deviation from the baseline
        public init(name: String, metrics: [PerformanceMetric] = [], baseline: Double? = nil, acceptableDeviation: Double? = nil) {
            self.name = name
            self.metrics = metrics
            self.baseline = baseline
            self.acceptableDeviation = acceptableDeviation
        }
        
        /// Add a metric to the history
        /// - Parameter metric: The metric to add
        public mutating func addMetric(_ metric: PerformanceMetric) {
            metrics.append(metric)
            metrics.sort { $0.timestamp < $1.timestamp }
        }
        
        /// Get the average value of the metric over the history
        public var average: Double {
            guard !metrics.isEmpty else { return 0 }
            let sum = metrics.reduce(0) { $0 + $1.value }
            return sum / Double(metrics.count)
        }
        
        /// Get the standard deviation of the metric over the history
        public var standardDeviation: Double {
            guard metrics.count > 1 else { return 0 }
            let avg = average
            let sumOfSquaredDifferences = metrics.reduce(0) { $0 + pow($1.value - avg, 2) }
            return sqrt(sumOfSquaredDifferences / Double(metrics.count - 1))
        }
        
        /// Get the minimum value of the metric over the history
        public var minimum: Double {
            return metrics.min { $0.value < $1.value }?.value ?? 0
        }
        
        /// Get the maximum value of the metric over the history
        public var maximum: Double {
            return metrics.max { $0.value < $1.value }?.value ?? 0
        }
        
        /// Get the most recent value of the metric
        public var mostRecent: Double {
            return metrics.max { $0.timestamp < $1.timestamp }?.value ?? 0
        }
        
        /// Check if the most recent value is within the acceptable deviation from the baseline
        public var isWithinAcceptableDeviation: Bool {
            guard let baseline = baseline, let acceptableDeviation = acceptableDeviation, !metrics.isEmpty else {
                return true
            }
            
            let mostRecentValue = mostRecent
            let deviation = abs(mostRecentValue - baseline) / baseline
            return deviation <= acceptableDeviation
        }
    }
    
    /// A performance test configuration
    public struct PerformanceTestConfig {
        /// The number of warm-up iterations to run
        public let warmupIterations: Int
        
        /// The number of measurement iterations to run
        public let measurementIterations: Int
        
        /// The maximum execution time allowed (in seconds)
        public let maxExecutionTime: Double
        
        /// The maximum memory usage allowed (in MB)
        public let maxMemoryUsage: Int
        
        /// Create a new performance test configuration
        /// - Parameters:
        ///   - warmupIterations: The number of warm-up iterations to run
        ///   - measurementIterations: The number of measurement iterations to run
        ///   - maxExecutionTime: The maximum execution time allowed (in seconds)
        ///   - maxMemoryUsage: The maximum memory usage allowed (in MB)
        public init(
            warmupIterations: Int = TestConfig.shared.performanceTestWarmupIterations,
            measurementIterations: Int = TestConfig.shared.performanceTestMeasurementIterations,
            maxExecutionTime: Double = TestConfig.shared.maxExecutionTimeSeconds,
            maxMemoryUsage: Int = TestConfig.shared.maxMemoryUsageMB
        ) {
            self.warmupIterations = warmupIterations
            self.measurementIterations = measurementIterations
            self.maxExecutionTime = maxExecutionTime
            self.maxMemoryUsage = maxMemoryUsage
        }
    }
    
    // MARK: - Performance Measurement
    
    /// Measure the execution time of a block
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - config: The performance test configuration
    ///   - block: The block to measure
    /// - Returns: The performance metric
    public static func measureExecutionTime(
        name: String,
        config: PerformanceTestConfig = PerformanceTestConfig(),
        block: () -> Void
    ) -> PerformanceMetric {
        // Run warm-up iterations
        for _ in 0..<config.warmupIterations {
            block()
        }
        
        // Run measurement iterations
        var measurements = [Double]()
        for _ in 0..<config.measurementIterations {
            let start = Date()
            block()
            let end = Date()
            let duration = end.timeIntervalSince(start)
            measurements.append(duration)
        }
        
        // Calculate the average
        let average = measurements.reduce(0, +) / Double(measurements.count)
        
        // Create metadata
        let metadata: [String: String] = [
            "iterations": String(config.measurementIterations),
            "min": String(format: "%.6f", measurements.min() ?? 0),
            "max": String(format: "%.6f", measurements.max() ?? 0),
            "standardDeviation": String(format: "%.6f", calculateStandardDeviation(measurements))
        ]
        
        return PerformanceMetric(name: name, value: average, units: "seconds", metadata: metadata)
    }
    
    /// Measure the memory usage of a block
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - config: The performance test configuration
    ///   - block: The block to measure
    /// - Returns: The performance metric
    public static func measureMemoryUsage(
        name: String,
        config: PerformanceTestConfig = PerformanceTestConfig(),
        block: () -> Void
    ) -> PerformanceMetric {
        // Get the initial memory usage
        let initialMemoryUsage = currentMemoryUsage()
        
        // Run the block
        block()
        
        // Get the final memory usage
        let finalMemoryUsage = currentMemoryUsage()
        
        // Calculate the difference
        let memoryUsageMB = (finalMemoryUsage - initialMemoryUsage) / (1024 * 1024)
        
        // Create metadata
        let metadata: [String: String] = [
            "initialUsageMB": String(format: "%.2f", Double(initialMemoryUsage) / (1024 * 1024)),
            "finalUsageMB": String(format: "%.2f", Double(finalMemoryUsage) / (1024 * 1024))
        ]
        
        return PerformanceMetric(name: name, value: Double(memoryUsageMB), units: "MB", metadata: metadata)
    }
    
    /// Get the current memory usage
    /// - Returns: The current memory usage in bytes
    static func currentMemoryUsage() -> UInt64 {
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
            return info.resident_size
        } else {
            return 0
        }
    }
    
    /// Calculate the standard deviation of an array of values
    /// - Parameter values: The values to calculate the standard deviation of
    /// - Returns: The standard deviation
    static func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) }
        return sqrt(variance / Double(values.count - 1))
    }
    
    // MARK: - Performance Tracking
    
    /// Record a performance metric and save it to the history
    /// - Parameters:
    ///   - metric: The metric to record
    ///   - testClass: The test class
    /// - Returns: The updated metric history
    @discardableResult
    public static func recordPerformanceMetric(
        _ metric: PerformanceMetric,
        in testClass: XCTestCase.Type
    ) -> PerformanceMetricHistory {
        let config = TestConfig.shared
        let historyURL = config.performanceResultURL(for: metric.name, in: testClass)
        
        // Create directory if it doesn't exist
        let directory = historyURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Load existing history or create a new one
        var history: PerformanceMetricHistory
        
        if FileManager.default.fileExists(atPath: historyURL.path),
           let data = try? Data(contentsOf: historyURL),
           let loadedHistory = try? JSONDecoder().decode(PerformanceMetricHistory.self, from: data) {
            history = loadedHistory
        } else {
            history = PerformanceMetricHistory(name: metric.name)
        }
        
        // Add the new metric
        history.addMetric(metric)
        
        // Save the updated history
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(history) {
            try? data.write(to: historyURL)
        }
        
        return history
    }
    
    /// Get the performance metric history for a metric
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - testClass: The test class
    /// - Returns: The metric history, or nil if it doesn't exist
    public static func getPerformanceMetricHistory(
        for name: String,
        in testClass: XCTestCase.Type
    ) -> PerformanceMetricHistory? {
        let config = TestConfig.shared
        let historyURL = config.performanceResultURL(for: name, in: testClass)
        
        guard FileManager.default.fileExists(atPath: historyURL.path),
              let data = try? Data(contentsOf: historyURL),
              let history = try? JSONDecoder().decode(PerformanceMetricHistory.self, from: data) else {
            return nil
        }
        
        return history
    }
    
    /// Get the baseline value for a metric
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - testClass: The test class
    ///   - defaultValue: The default value to return if no baseline exists
    /// - Returns: The baseline value
    public static func getBaseline(
        for name: String,
        in testClass: XCTestCase.Type,
        defaultValue: Double
    ) -> Double {
        guard let history = getPerformanceMetricHistory(for: name, in: testClass),
              let baseline = history.baseline else {
            return defaultValue
        }
        
        return baseline
    }
    
    /// Set the baseline value for a metric
    /// - Parameters:
    ///   - value: The baseline value
    ///   - name: The name of the metric
    ///   - testClass: The test class
    ///   - acceptableDeviation: The acceptable deviation from the baseline
    public static func setBaseline(
        value: Double,
        for name: String,
        in testClass: XCTestCase.Type,
        acceptableDeviation: Double = 0.1
    ) {
        let config = TestConfig.shared
        let historyURL = config.performanceResultURL(for: name, in: testClass)
        
        // Load existing history or create a new one
        var history: PerformanceMetricHistory
        
        if FileManager.default.fileExists(atPath: historyURL.path),
           let data = try? Data(contentsOf: historyURL),
           let loadedHistory = try? JSONDecoder().decode(PerformanceMetricHistory.self, from: data) {
            history = loadedHistory
        } else {
            history = PerformanceMetricHistory(name: name)
        }
        
        // Update the baseline
        history.baseline = value
        history.acceptableDeviation = acceptableDeviation
        
        // Save the updated history
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(history) {
            try? data.write(to: historyURL)
        }
    }
    
    /// Check if a metric value is within the acceptable deviation from the baseline
    /// - Parameters:
    ///   - value: The value to check
    ///   - name: The name of the metric
    ///   - testClass: The test class
    ///   - defaultAcceptable: Whether to consider the value acceptable if no baseline exists
    /// - Returns: Whether the value is within the acceptable deviation
    public static func isWithinAcceptableDeviation(
        value: Double,
        for name: String,
        in testClass: XCTestCase.Type,
        defaultAcceptable: Bool = true
    ) -> Bool {
        guard let history = getPerformanceMetricHistory(for: name, in: testClass),
              let baseline = history.baseline,
              let acceptableDeviation = history.acceptableDeviation else {
            return defaultAcceptable
        }
        
        let deviation = abs(value - baseline) / baseline
        return deviation <= acceptableDeviation
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /// Measure the execution time of a block and assert that it's within the acceptable deviation
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - config: The performance test configuration
    ///   - block: The block to measure
    /// - Returns: The measured execution time in seconds
    @discardableResult
    public func measureExecutionTime(
        name: String,
        config: PerformanceTestUtility.PerformanceTestConfig = PerformanceTestUtility.PerformanceTestConfig(),
        file: StaticString = #file,
        line: UInt = #line,
        block: () -> Void
    ) -> Double {
        let testClass = type(of: self)
        
        // Measure the execution time
        let metric = PerformanceTestUtility.measureExecutionTime(name: name, config: config, block: block)
        
        // Record the metric
        let history = PerformanceTestUtility.recordPerformanceMetric(metric, in: testClass)
        
        // Get the baseline
        if let baseline = history.baseline, let acceptableDeviation = history.acceptableDeviation {
            // Check if the measured value is within the acceptable deviation
            let deviation = abs(metric.value - baseline) / baseline
            let isWithinDeviation = deviation <= acceptableDeviation
            
            // Assert that the measured value is within the acceptable deviation
            XCTAssertTrue(
                isWithinDeviation,
                "Execution time for \(name) is \(metric.value) seconds, which exceeds the acceptable deviation of \(acceptableDeviation * 100)% from the baseline of \(baseline) seconds (deviation: \(deviation * 100)%)",
                file: file,
                line: line
            )
            
            // Check if the measured value exceeds the maximum allowed execution time
            XCTAssertLessThanOrEqual(
                metric.value,
                config.maxExecutionTime,
                "Execution time for \(name) is \(metric.value) seconds, which exceeds the maximum allowed execution time of \(config.maxExecutionTime) seconds",
                file: file,
                line: line
            )
        } else {
            // No baseline exists, so just check against the maximum allowed execution time
            XCTAssertLessThanOrEqual(
                metric.value,
                config.maxExecutionTime,
                "Execution time for \(name) is \(metric.value) seconds, which exceeds the maximum allowed execution time of \(config.maxExecutionTime) seconds",
                file: file,
                line: line
            )
            
            // Set the current value as the baseline if we're not in CI
            if !TestConfig.shared.isRunningInCI {
                PerformanceTestUtility.setBaseline(value: metric.value, for: name, in: testClass)
            }
        }
        
        return metric.value
    }
    
    /// Measure the memory usage of a block and assert that it's within the acceptable deviation
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - config: The performance test configuration
    ///   - block: The block to measure
    /// - Returns: The measured memory usage in MB
    @discardableResult
    public func measureMemoryUsage(
        name: String,
        config: PerformanceTestUtility.PerformanceTestConfig = PerformanceTestUtility.PerformanceTestConfig(),
        file: StaticString = #file,
        line: UInt = #line,
        block: () -> Void
    ) -> Double {
        let testClass = type(of: self)
        
        // Measure the memory usage
        let metric = PerformanceTestUtility.measureMemoryUsage(name: name, config: config, block: block)
        
        // Record the metric
        let history = PerformanceTestUtility.recordPerformanceMetric(metric, in: testClass)
        
        // Get the baseline
        if let baseline = history.baseline, let acceptableDeviation = history.acceptableDeviation {
            // Check if the measured value is within the acceptable deviation
            let deviation = abs(metric.value - baseline) / baseline
            let isWithinDeviation = deviation <= acceptableDeviation
            
            // Assert that the measured value is within the acceptable deviation
            XCTAssertTrue(
                isWithinDeviation,
                "Memory usage for \(name) is \(metric.value) MB, which exceeds the acceptable deviation of \(acceptableDeviation * 100)% from the baseline of \(baseline) MB (deviation: \(deviation * 100)%)",
                file: file,
                line: line
            )
            
            // Check if the measured value exceeds the maximum allowed memory usage
            XCTAssertLessThanOrEqual(
                metric.value,
                Double(config.maxMemoryUsage),
                "Memory usage for \(name) is \(metric.value) MB, which exceeds the maximum allowed memory usage of \(config.maxMemoryUsage) MB",
                file: file,
                line: line
            )
        } else {
            // No baseline exists, so just check against the maximum allowed memory usage
            XCTAssertLessThanOrEqual(
                metric.value,
                Double(config.maxMemoryUsage),
                "Memory usage for \(name) is \(metric.value) MB, which exceeds the maximum allowed memory usage of \(config.maxMemoryUsage) MB",
                file: file,
                line: line
            )
            
            // Set the current value as the baseline if we're not in CI
            if !TestConfig.shared.isRunningInCI {
                PerformanceTestUtility.setBaseline(value: metric.value, for: name, in: testClass)
            }
        }
        
        return metric.value
    }
} 