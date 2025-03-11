import XCTest
import Foundation

/// A utility class for performance testing and benchmarking
public class PerformanceTestUtility {
    
    // MARK: - Types
    
    /// Represents a performance metric with metadata
    public struct PerformanceMetric {
        /// Name of the metric
        public let name: String
        
        /// Value of the metric
        public let value: Double
        
        /// Unit of measurement
        public let unit: String
        
        /// Whether lower values are better for this metric (true for time, memory, etc.)
        public let lowerIsBetter: Bool
        
        /// The baseline value for comparison, if any
        public let baseline: Double?
        
        /// Acceptable range as a percentage of baseline (0.0-1.0)
        public let acceptableRange: Double
        
        /// Whether the metric is within acceptable range
        public var isAcceptable: Bool {
            guard let baseline = baseline else { return true }
            
            let difference = abs(value - baseline) / baseline
            return difference <= acceptableRange
        }
        
        /// Formatted string representation of the value with unit
        public var formattedValue: String {
            switch unit {
            case "ms":
                return String(format: "%.2f ms", value)
            case "s":
                return String(format: "%.3f s", value)
            case "MB":
                return String(format: "%.2f MB", value)
            case "KB":
                return String(format: "%.1f KB", value)
            case "%":
                return String(format: "%.1f%%", value * 100)
            default:
                return String(format: "%.3f %@", value, unit)
            }
        }
        
        /// Formatted comparison with baseline
        public var comparisonString: String {
            guard let baseline = baseline else {
                return "No baseline"
            }
            
            let difference = value - baseline
            let percentChange = (difference / baseline) * 100
            
            let changeSymbol = difference > 0 ? "+" : ""
            let betterWorse = (difference > 0 && lowerIsBetter) || (difference < 0 && !lowerIsBetter) ? "worse" : "better"
            
            return "\(changeSymbol)\(String(format: "%.1f%%", percentChange)) \(betterWorse) than baseline"
        }
    }
    
    /// Represents the result of a performance test
    public struct TestResult {
        /// Name of the test
        public let testName: String
        
        /// Collected metrics
        public let metrics: [PerformanceMetric]
        
        /// Date the test was run
        public let date: Date
        
        /// Environment information
        public let environment: [String: String]
        
        /// Whether all metrics are acceptable
        public var isAcceptable: Bool {
            metrics.allSatisfy { $0.isAcceptable }
        }
    }
    
    // MARK: - Properties
    
    /// Results collected during the test run
    private static var results: [TestResult] = []
    
    /// History file for persisting performance metrics
    private static let historyFilename = "performance_history.csv"
    
    /// Directory where results are stored
    private static var resultsDirectory: URL {
        let fileManager = FileManager.default
        let tmpDir = NSTemporaryDirectory()
        let dirPath = tmpDir + "/PerformanceResults"
        
        // Check if running in CI
        if let ciDir = ProcessInfo.processInfo.environment["CI_PERFORMANCE_RESULTS_DIR"] {
            return URL(fileURLWithPath: ciDir)
        }
        
        // Try to find a better location if available
        if let buildDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            return URL(fileURLWithPath: buildDir).appendingPathComponent("PerformanceResults")
        }
        
        return URL(fileURLWithPath: dirPath)
    }
    
    // MARK: - Public Methods
    
    /// Measures the execution time of a block
    ///
    /// - Parameters:
    ///   - name: Name of the metric
    ///   - baselineValue: Optional baseline for comparison
    ///   - acceptableRange: Acceptable deviation from baseline (percentage, 0.0-1.0)
    ///   - block: The block to measure
    /// - Returns: A performance metric with the execution time
    public static func measureExecutionTime(
        name: String,
        baselineValue: Double? = nil,
        acceptableRange: Double = 0.1, // 10% deviation allowed by default
        block: () -> Void
    ) -> PerformanceMetric {
        let start = CFAbsoluteTimeGetCurrent()
        
        block()
        
        let end = CFAbsoluteTimeGetCurrent()
        let timeInSeconds = end - start
        let timeInMs = timeInSeconds * 1000
        
        return PerformanceMetric(
            name: name,
            value: timeInMs,
            unit: "ms",
            lowerIsBetter: true,
            baseline: baselineValue,
            acceptableRange: acceptableRange
        )
    }
    
    /// Measures the memory usage of a block
    ///
    /// - Parameters:
    ///   - name: Name of the metric
    ///   - baselineValue: Optional baseline for comparison
    ///   - acceptableRange: Acceptable deviation from baseline (percentage, 0.0-1.0)
    ///   - block: The block to measure
    /// - Returns: A performance metric with the memory usage
    public static func measureMemoryUsage(
        name: String,
        baselineValue: Double? = nil,
        acceptableRange: Double = 0.15, // 15% deviation allowed by default
        block: () -> Void
    ) -> PerformanceMetric {
        // Get initial memory info
        let initialMemory = reportMemoryUsage()
        
        // Run the block
        block()
        
        // Get final memory info
        let finalMemory = reportMemoryUsage()
        
        // Calculate difference
        let memoryUsed = finalMemory - initialMemory
        let memoryInMB = Double(memoryUsed) / (1024 * 1024)
        
        return PerformanceMetric(
            name: name,
            value: memoryInMB,
            unit: "MB",
            lowerIsBetter: true,
            baseline: baselineValue,
            acceptableRange: acceptableRange
        )
    }
    
    /// Records the result of a performance test
    ///
    /// - Parameters:
    ///   - testName: Name of the test
    ///   - metrics: Array of metrics collected
    /// - Returns: The test result
    @discardableResult
    public static func recordResult(testName: String, metrics: [PerformanceMetric]) -> TestResult {
        // Collect environment info
        let environment = collectEnvironmentInfo()
        
        // Create result
        let result = TestResult(
            testName: testName,
            metrics: metrics,
            date: Date(),
            environment: environment
        )
        
        // Save result
        results.append(result)
        
        // Save to history file
        saveResultToHistory(result)
        
        return result
    }
    
    /// Reports the results of performance tests
    ///
    /// - Parameters:
    ///   - testCase: The test case to report for
    ///   - metrics: Array of metrics to report
    ///   - failIfUnacceptable: Whether to fail the test if metrics are unacceptable
    public static func reportResults(
        in testCase: XCTestCase,
        metrics: [PerformanceMetric]? = nil,
        failIfUnacceptable: Bool = true
    ) {
        // If specific metrics are provided, use those, otherwise use last result
        let metricsToReport: [PerformanceMetric]
        
        if let metrics = metrics {
            metricsToReport = metrics
        } else if let lastResult = results.last {
            metricsToReport = lastResult.metrics
        } else {
            return // Nothing to report
        }
        
        // Report each metric
        for metric in metricsToReport {
            // Format basic information
            let metricInfo = "\(metric.name): \(metric.formattedValue)"
            
            // Add baseline comparison if available
            let comparison = metric.baseline != nil ? " (\(metric.comparisonString))" : ""
            
            // Decide if this is passing or failing
            let passed = !failIfUnacceptable || metric.isAcceptable
            
            if passed {
                print("✅ \(metricInfo)\(comparison)")
                XCTAssertTrue(true, "\(metricInfo)\(comparison)")
            } else {
                print("❌ \(metricInfo)\(comparison) - Outside acceptable range")
                XCTFail("\(metricInfo)\(comparison) - Outside acceptable range")
            }
        }
    }

    /// Measures the performance of a block with multiple iterations
    ///
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of iterations to run
    ///   - setup: Optional setup closure run once before measurements
    ///   - block: The block to measure
    public static func measurePerformance(
        name: String,
        iterations: Int = 10,
        setup: (() -> Void)? = nil,
        block: @escaping () -> Void
    ) {
        // Run optional setup
        setup?()
        
        var times = [Double]()
        times.reserveCapacity(iterations)
        
        // Warmup run (to minimize JIT compilation effects)
        block()
        
        // Actual measured runs
        for _ in 1...iterations {
            let start = CFAbsoluteTimeGetCurrent()
            block()
            let end = CFAbsoluteTimeGetCurrent()
            times.append((end - start) * 1000) // Convert to ms
        }
        
        // Calculate statistics
        let totalTime = times.reduce(0, +)
        let averageTime = totalTime / Double(times.count)
        
        // Sort times for percentile calculations
        let sortedTimes = times.sorted()
        let medianTime = calculateMedian(sortedTimes)
        let p95Time = calculatePercentile(sortedTimes, percentile: 0.95)
        
        // Create metrics
        let metrics = [
            PerformanceMetric(
                name: "\(name) (avg)",
                value: averageTime,
                unit: "ms",
                lowerIsBetter: true,
                baseline: getBaseline(for: "\(name) (avg)"),
                acceptableRange: 0.1
            ),
            PerformanceMetric(
                name: "\(name) (median)",
                value: medianTime,
                unit: "ms",
                lowerIsBetter: true,
                baseline: getBaseline(for: "\(name) (median)"),
                acceptableRange: 0.1
            ),
            PerformanceMetric(
                name: "\(name) (p95)",
                value: p95Time,
                unit: "ms",
                lowerIsBetter: true,
                baseline: getBaseline(for: "\(name) (p95)"),
                acceptableRange: 0.15
            )
        ]
        
        // Record the result
        recordResult(testName: name, metrics: metrics)
    }
    
    // MARK: - Private Helper Methods
    
    /// Gets the baseline value for a metric from history
    private static func getBaseline(for metricName: String) -> Double? {
        // Try to load from environment (useful in CI)
        if let baselineEnv = ProcessInfo.processInfo.environment["PERF_BASELINE_\(metricName.replacingOccurrences(of: " ", with: "_"))"],
           let baseline = Double(baselineEnv) {
            return baseline
        }
        
        // Otherwise try to load from history file
        let historyURL = resultsDirectory.appendingPathComponent(historyFilename)
        
        guard FileManager.default.fileExists(atPath: historyURL.path),
              let csv = try? String(contentsOf: historyURL, encoding: .utf8) else {
            return nil
        }
        
        let rows = csv.split(separator: "\n").map { String($0) }
        guard rows.count > 1 else { return nil }
        
        // Parse header to find column index for this metric
        let header = rows[0].split(separator: ",").map { String($0) }
        guard let metricIndex = header.firstIndex(of: metricName) else { return nil }
        
        // Get values from last 5 rows (or fewer if not available)
        let startRow = max(1, rows.count - 5)
        var values = [Double]()
        
        for i in startRow..<rows.count {
            let columns = rows[i].split(separator: ",").map { String($0) }
            guard columns.count > metricIndex, let value = Double(columns[metricIndex]) else { continue }
            values.append(value)
        }
        
        // Return median of values as baseline
        return values.isEmpty ? nil : calculateMedian(values.sorted())
    }
    
    /// Saves a test result to the history file
    private static func saveResultToHistory(_ result: TestResult) {
        ensureDirectoryExists()
        
        let historyURL = resultsDirectory.appendingPathComponent(historyFilename)
        let fileManager = FileManager.default
        
        // Create or append to history file
        if !fileManager.fileExists(atPath: historyURL.path) {
            // Create new file with header
            var header = "Date,Environment"
            for metric in result.metrics {
                header += ",\(metric.name)"
            }
            
            try? header.write(to: historyURL, atomically: true, encoding: .utf8)
        }
        
        // Format row to append
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: result.date)
        
        let envString = "Swift-\(result.environment["swift_version"] ?? "unknown")"
        
        var row = "\n\(dateString),\(envString)"
        
        // Get existing header to ensure columns match
        if let existingContent = try? String(contentsOf: historyURL, encoding: .utf8),
           let headerLine = existingContent.split(separator: "\n").first {
            
            let headerColumns = String(headerLine).split(separator: ",").map { String($0) }
            
            // Skip Date and Environment
            for i in 2..<headerColumns.count {
                let metricName = headerColumns[i]
                if let metric = result.metrics.first(where: { $0.name == metricName }) {
                    row += ",\(metric.value)"
                } else {
                    row += "," // Empty value for missing metric
                }
            }
        } else {
            // Just append all metrics in order
            for metric in result.metrics {
                row += ",\(metric.value)"
            }
        }
        
        // Append to file
        if let fileHandle = FileHandle(forWritingAtPath: historyURL.path) {
            fileHandle.seekToEndOfFile()
            if let data = row.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
    }
    
    /// Collects environment information
    private static func collectEnvironmentInfo() -> [String: String] {
        var info = [String: String]()
        
        // Swift version
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Extract Swift version
                if let range = output.range(of: "Swift version ([0-9\\.]+)", options: .regularExpression) {
                    let versionFull = String(output[range])
                    if let versionNumberRange = versionFull.range(of: "[0-9\\.]+", options: .regularExpression) {
                        info["swift_version"] = String(versionFull[versionNumberRange])
                    } else {
                        info["swift_version"] = "unknown"
                    }
                } else {
                    info["swift_version"] = "unknown"
                }
            }
        } catch {
            info["swift_version"] = "unknown"
        }
        
        // OS version
        info["os"] = ProcessInfo.processInfo.operatingSystemVersionString
        
        // Device model
        if let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            info["device"] = "Simulator-\(model)"
        } else {
            var size: Int = 0
            var hwModel = [CChar](repeating: 0, count: 100)
            var mib = [CTL_HW, HW_MODEL]
            
            size = hwModel.count
            let result = sysctl(&mib, u_int(mib.count), &hwModel, &size, nil, 0)
            if result == 0 {
                info["device"] = String(cString: hwModel)
            } else {
                info["device"] = "unknown"
            }
        }
        
        // CI information
        if let ciSystem = ProcessInfo.processInfo.environment["CI"] {
            info["ci"] = ciSystem
        }
        
        return info
    }
    
    /// Ensures the results directory exists
    private static func ensureDirectoryExists() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: resultsDirectory.path) {
            do {
                try fileManager.createDirectory(at: resultsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating results directory: \(error)")
            }
        }
    }
    
    /// Reports the current memory usage in bytes
    private static func reportMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPtr,
                    &count
                )
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        return info.resident_size
    }
    
    /// Calculates the median value of a sorted array
    private static func calculateMedian(_ sortedArray: [Double]) -> Double {
        guard !sortedArray.isEmpty else { return 0 }
        
        if sortedArray.count % 2 == 0 {
            let midIndex = sortedArray.count / 2
            return (sortedArray[midIndex-1] + sortedArray[midIndex]) / 2
        } else {
            return sortedArray[sortedArray.count / 2]
        }
    }
    
    /// Calculates a percentile value from a sorted array
    private static func calculatePercentile(_ sortedArray: [Double], percentile: Double) -> Double {
        guard !sortedArray.isEmpty else { return 0 }
        
        let index = Int((Double(sortedArray.count) * percentile).rounded(.down))
        return sortedArray[min(max(0, index), sortedArray.count - 1)]
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    /// Measures and reports performance of a block
    ///
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - iterations: Number of iterations to run
    ///   - setup: Optional setup closure run once before measurements
    ///   - block: The block to measure
    public func measurePerformance(
        name: String,
        iterations: Int = 10,
        setup: (() -> Void)? = nil,
        block: @escaping () -> Void
    ) {
        PerformanceTestUtility.measurePerformance(
            name: name,
            iterations: iterations,
            setup: setup,
            block: block
        )
    }
    
    /// Reports all performance results collected during this test
    public func reportPerformanceResults() {
        PerformanceTestUtility.reportResults(in: self)
    }
} 