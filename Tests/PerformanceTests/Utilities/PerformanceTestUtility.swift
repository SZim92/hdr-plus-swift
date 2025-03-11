import XCTest
import Foundation

/// A utility class for performance testing
class PerformanceTestUtility {
    
    /// Performance metric tracking results
    struct PerformanceMetric {
        /// The name of the metric
        let name: String
        
        /// The value of the metric
        let value: Double
        
        /// The unit of the metric
        let unit: String
        
        /// Whether lower values are better (default: true)
        let lowerIsBetter: Bool
        
        /// Baseline value for comparison
        let baseline: Double?
        
        /// Whether the metric is within acceptable range of baseline
        var isAcceptable: Bool {
            guard let baseline = baseline else { return true }
            
            let percentChange = ((value - baseline) / baseline) * 100.0
            let acceptableRange = 10.0 // 10% change is acceptable
            
            if lowerIsBetter {
                return percentChange <= acceptableRange
            } else {
                return percentChange >= -acceptableRange
            }
        }
        
        /// String representation of the metric
        var description: String {
            let baselineStr = baseline != nil ? " (baseline: \(String(format: "%.2f", baseline!)) \(unit))" : ""
            return "\(name): \(String(format: "%.2f", value)) \(unit)\(baselineStr)"
        }
    }
    
    /// Performance test result
    struct TestResult {
        /// The name of the test
        let testName: String
        
        /// Performance metrics collected
        let metrics: [PerformanceMetric]
        
        /// Date when the test was run
        let date: Date
        
        /// Environment information
        let environment: [String: String]
        
        /// Whether all metrics are acceptable
        var isAcceptable: Bool {
            return metrics.allSatisfy { $0.isAcceptable }
        }
    }
    
    /// Singleton instance
    static let shared = PerformanceTestUtility()
    
    /// Array of test results
    private(set) var results: [TestResult] = []
    
    /// Directory for storing performance results
    private let resultDirectory = "PerformanceResults"
    
    /// CSV file for storing historical data
    private let historyFile = "performance_history.csv"
    
    /**
     Measure execution time of a block
     
     - Parameters:
        - name: The name of the measured operation
        - iterations: Number of iterations to average
        - block: The block to measure
     - Returns: A PerformanceMetric for the measured operation
     */
    func measureExecutionTime(name: String, iterations: Int = 10, _ block: () -> Void) -> PerformanceMetric {
        var times: [TimeInterval] = []
        
        // Warm-up run (not counted)
        block()
        
        // Measured runs
        for _ in 0..<iterations {
            let start = Date()
            block()
            let end = Date()
            times.append(end.timeIntervalSince(start))
        }
        
        // Calculate average time in milliseconds
        let averageTime = times.reduce(0.0, +) / Double(times.count) * 1000.0
        
        // Get baseline if available
        let baseline = getBaseline(for: name)
        
        return PerformanceMetric(name: name, value: averageTime, unit: "ms", lowerIsBetter: true, baseline: baseline)
    }
    
    /**
     Measure memory usage of a block
     
     - Parameters:
        - name: The name of the measured operation
        - block: The block to measure
     - Returns: A PerformanceMetric for memory usage
     */
    func measureMemoryUsage(name: String, _ block: () -> Void) -> PerformanceMetric {
        // Get initial memory usage
        let initialUsage = getCurrentMemoryUsage()
        
        // Run the block
        block()
        
        // Get final memory usage
        let finalUsage = getCurrentMemoryUsage()
        
        // Calculate the difference in megabytes
        let usageMB = Double(finalUsage - initialUsage) / 1024.0 / 1024.0
        
        // Get baseline if available
        let baseline = getBaseline(for: "\(name)_memory")
        
        return PerformanceMetric(name: "\(name) Memory", value: usageMB, unit: "MB", lowerIsBetter: true, baseline: baseline)
    }
    
    /**
     Record a test result
     
     - Parameters:
        - testName: The name of the test
        - metrics: The metrics to record
     */
    func recordResult(testName: String, metrics: [PerformanceMetric]) {
        let environment = collectEnvironmentInfo()
        let result = TestResult(
            testName: testName,
            metrics: metrics,
            date: Date(),
            environment: environment
        )
        
        results.append(result)
        saveResult(result)
    }
    
    /**
     Report performance test results
     
     - Parameter testCase: The XCTestCase instance
     */
    func reportResults(in testCase: XCTestCase) {
        for result in results {
            for metric in result.metrics {
                let acceptableStr = metric.isAcceptable ? "✅" : "❌"
                print("\(result.testName) - \(metric.description) \(acceptableStr)")
                
                if !metric.isAcceptable, let baseline = metric.baseline {
                    let percentChange = ((metric.value - baseline) / baseline) * 100.0
                    let changeStr = String(format: "%.1f%%", abs(percentChange))
                    let direction = percentChange > 0 ? "increased" : "decreased"
                    let impact = metric.lowerIsBetter == (percentChange > 0) ? "worse" : "better"
                    
                    let message = "\(metric.name) has \(direction) by \(changeStr) (\(impact) than baseline)"
                    XCTFail(message)
                }
            }
        }
    }
    
    /**
     Get baseline value for a metric
     
     - Parameter name: The name of the metric
     - Returns: The baseline value, or nil if no baseline exists
     */
    private func getBaseline(for name: String) -> Double? {
        // Check if history file exists
        let fileManager = FileManager.default
        ensureDirectoryExists(resultDirectory)
        
        let historyPath = "\(resultDirectory)/\(historyFile)"
        guard fileManager.fileExists(atPath: historyPath) else {
            return nil
        }
        
        do {
            let data = try String(contentsOfFile: historyPath, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            // Parse CSV header to find column for the metric
            guard let header = lines.first else { return nil }
            let columns = header.components(separatedBy: ",")
            
            guard let nameIndex = columns.firstIndex(of: "Metric") else { return nil }
            guard let valueIndex = columns.firstIndex(of: "Value") else { return nil }
            
            // Find the most recent value for the metric
            for line in lines.dropFirst().reversed() {
                let parts = line.components(separatedBy: ",")
                guard parts.count > max(nameIndex, valueIndex) else { continue }
                
                if parts[nameIndex] == name, let value = Double(parts[valueIndex]) {
                    return value
                }
            }
            
            return nil
        } catch {
            print("Error reading performance history: \(error)")
            return nil
        }
    }
    
    /**
     Save a test result to the history file
     
     - Parameter result: The test result to save
     */
    private func saveResult(_ result: TestResult) {
        ensureDirectoryExists(resultDirectory)
        
        let historyPath = "\(resultDirectory)/\(historyFile)"
        let fileManager = FileManager.default
        
        // Create the file with header if it doesn't exist
        if !fileManager.fileExists(atPath: historyPath) {
            let header = "Date,Test,Metric,Value,Unit,Platform,Swift Version\n"
            try? header.write(toFile: historyPath, atomically: true, encoding: .utf8)
        }
        
        // Get existing content
        var content = (try? String(contentsOfFile: historyPath, encoding: .utf8)) ?? ""
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = dateFormatter.string(from: result.date)
        
        // Add new results
        for metric in result.metrics {
            let platform = result.environment["platform"] ?? "unknown"
            let swiftVersion = result.environment["swiftVersion"] ?? "unknown"
            
            let line = "\(dateStr),\(result.testName),\(metric.name),\(metric.value),\(metric.unit),\(platform),\(swiftVersion)\n"
            content.append(line)
        }
        
        // Write updated content
        try? content.write(toFile: historyPath, atomically: true, encoding: .utf8)
    }
    
    /**
     Collect environment information
     
     - Returns: Dictionary of environment information
     */
    private func collectEnvironmentInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // Get platform
        #if os(macOS)
        info["platform"] = "macOS"
        info["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        #elseif os(iOS)
        info["platform"] = "iOS"
        #endif
        
        // Get Swift version
        #if swift(>=5.9)
        info["swiftVersion"] = "5.9+"
        #elseif swift(>=5.8)
        info["swiftVersion"] = "5.8"
        #elseif swift(>=5.7)
        info["swiftVersion"] = "5.7"
        #else
        info["swiftVersion"] = "5.6 or earlier"
        #endif
        
        // Get CPU info
        let processInfo = ProcessInfo.processInfo
        info["processorCount"] = "\(processInfo.processorCount)"
        info["physicalMemory"] = "\(processInfo.physicalMemory / 1024 / 1024) MB"
        
        return info
    }
    
    /**
     Get current memory usage
     
     - Returns: Current memory usage in bytes
     */
    private func getCurrentMemoryUsage() -> UInt64 {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return taskInfo.phys_footprint
        }
        
        return 0
    }
    
    /**
     Ensure a directory exists, creating it if necessary
     
     - Parameter path: The directory path
     */
    private func ensureDirectoryExists(_ path: String) {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    /**
     Measure performance with automatic reporting
     
     - Parameters:
        - name: The name of the operation
        - iterations: Number of iterations to average
        - block: The block to measure
     */
    func measurePerformance(name: String, iterations: Int = 10, _ block: () -> Void) {
        let executionMetric = PerformanceTestUtility.shared.measureExecutionTime(name: name, iterations: iterations, block)
        let memoryMetric = PerformanceTestUtility.shared.measureMemoryUsage(name: name, block)
        
        PerformanceTestUtility.shared.recordResult(
            testName: self.name, 
            metrics: [executionMetric, memoryMetric]
        )
    }
    
    /**
     Report all performance metrics from the test case
     */
    func reportPerformanceResults() {
        PerformanceTestUtility.shared.reportResults(in: self)
    }
} 