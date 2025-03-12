import Foundation
import XCTest
import Metal

/// A helper for HDR processing performance tests
public class HDRPerformanceTestHelper {
    
    /// Shared instance
    public static let shared = HDRPerformanceTestHelper()
    
    /// Performance metrics for HDR processing
    public struct HDRPerformanceMetrics {
        /// Total processing time in seconds
        public let totalTime: TimeInterval
        /// Memory usage in bytes
        public let memoryUsage: Int64
        /// GPU time in seconds (if available)
        public let gpuTime: TimeInterval?
        /// Individual stage metrics
        public let stageMetrics: [String: StageMetric]
        /// Metal counters (if available)
        public let metalCounters: [String: Double]?
        
        /// Metric for a specific stage in the pipeline
        public struct StageMetric {
            /// Stage name
            public let name: String
            /// Processing time in seconds
            public let processingTime: TimeInterval
            /// Memory usage in bytes
            public let memoryUsage: Int64?
            /// GPU time in seconds (if available)
            public let gpuTime: TimeInterval?
            
            public init(
                name: String,
                processingTime: TimeInterval,
                memoryUsage: Int64? = nil,
                gpuTime: TimeInterval? = nil
            ) {
                self.name = name
                self.processingTime = processingTime
                self.memoryUsage = memoryUsage
                self.gpuTime = gpuTime
            }
        }
        
        public init(
            totalTime: TimeInterval,
            memoryUsage: Int64,
            gpuTime: TimeInterval? = nil,
            stageMetrics: [String: StageMetric] = [:],
            metalCounters: [String: Double]? = nil
        ) {
            self.totalTime = totalTime
            self.memoryUsage = memoryUsage
            self.gpuTime = gpuTime
            self.stageMetrics = stageMetrics
            self.metalCounters = metalCounters
        }
    }
    
    /// Metal performance tracking
    private var metalPerformanceTracking: Bool = false
    private var metalCounterSet: MTLCounterSet?
    private var metalCounterSampleBuffer: MTLCounterSampleBuffer?
    private var metalDevice: MTLDevice?
    
    /// Initialize with default settings
    public init() {
        setupMetal()
    }
    
    /// Setup Metal performance tracking if available
    private func setupMetal() {
        #if os(macOS) || os(iOS)
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal not available for performance tracking")
            return
        }
        
        metalDevice = device
        
        // Check if performance counters are supported
        if #available(macOS 10.15, iOS 14.0, *) {
            guard device.supportsCounterSampling(.timestamp) else {
                print("Metal timestamp counters not supported")
                return
            }
            
            // Get counter set for timestamps
            guard let counterSet = device.counterSets.first(where: { $0.name.contains("Timestamp") }) else {
                print("Metal timestamp counter set not available")
                return
            }
            
            metalCounterSet = counterSet
            metalPerformanceTracking = true
            
            print("Metal performance tracking enabled")
        }
        #endif
    }
    
    /// Create a Metal counter sample buffer if performance tracking is enabled
    private func createCounterSampleBuffer() {
        #if os(macOS) || os(iOS)
        if #available(macOS 10.15, iOS 14.0, *) {
            guard metalPerformanceTracking,
                  let device = metalDevice,
                  let counterSet = metalCounterSet else {
                return
            }
            
            do {
                metalCounterSampleBuffer = try device.makeCounterSampleBuffer(
                    descriptor: MTLCounterSampleBufferDescriptor().with {
                        $0.counterSet = counterSet
                        $0.sampleCount = 2  // Start and end
                    }
                )
            } catch {
                print("Failed to create Metal counter sample buffer: \(error)")
                metalPerformanceTracking = false
            }
        }
        #endif
    }
    
    /// Read Metal performance counters
    private func readMetalCounters() -> [String: Double]? {
        #if os(macOS) || os(iOS)
        if #available(macOS 10.15, iOS 14.0, *) {
            guard let sampleBuffer = metalCounterSampleBuffer else {
                return nil
            }
            
            var counters: [String: Double] = [:]
            
            do {
                // Get sample at index 0 (start) and 1 (end)
                guard let startSample = sampleBuffer.sample(at: 0),
                      let endSample = sampleBuffer.sample(at: 1) else {
                    return nil
                }
                
                // Calculate elapsed time
                if let startTimestamp = startSample.timestamp,
                   let endTimestamp = endSample.timestamp {
                    // Convert to milliseconds
                    let elapsedTimeMs = Double(endTimestamp - startTimestamp) / 1_000_000.0
                    counters["gpuTimeMs"] = elapsedTimeMs
                }
                
                return counters
            } catch {
                print("Failed to read Metal counters: \(error)")
                return nil
            }
        }
        #endif
        
        return nil
    }
    
    /// Measure the performance of an HDR processing operation
    /// - Parameters:
    ///   - name: Name of the operation (for reporting)
    ///   - iterations: Number of iterations to run
    ///   - setup: Optional setup closure to run before each iteration
    ///   - teardown: Optional teardown closure to run after each iteration
    ///   - operation: The operation to measure
    /// - Returns: Performance metrics
    public func measureHDRPerformance(
        name: String,
        iterations: Int = 10,
        setup: (() -> Void)? = nil,
        teardown: (() -> Void)? = nil,
        operation: @escaping () -> Void
    ) -> HDRPerformanceMetrics {
        print("📊 Measuring HDR performance for '\(name)' (\(iterations) iterations)...")
        
        // Create metrics arrays
        var totalTimes: [TimeInterval] = []
        var memoryUsages: [Int64] = []
        var gpuTimes: [TimeInterval] = []
        
        // Create counter sample buffer if needed
        createCounterSampleBuffer()
        
        // Run the operation multiple times
        for i in 1...iterations {
            print("  ▹ Iteration \(i)/\(iterations)...")
            
            // Run setup if provided
            setup?()
            
            // Create autorelease pool for better memory management
            autoreleasepool {
                // Record memory before
                let memoryBefore = getMemoryUsage()
                
                // Start GPU performance tracking if available
                #if os(macOS) || os(iOS)
                if #available(macOS 10.15, iOS 14.0, *) {
                    if metalPerformanceTracking,
                       let commandQueue = metalDevice?.makeCommandQueue(),
                       let sampleBuffer = metalCounterSampleBuffer,
                       let commandBuffer = commandQueue.makeCommandBuffer() {
                        
                        commandBuffer.sampleCounters(sampleBuffer, sampleIndex: 0, barrier: true)
                        commandBuffer.commit()
                    }
                }
                #endif
                
                // Measure operation time
                let startTime = Date()
                
                // Run the operation
                operation()
                
                // End time measurement
                let endTime = Date()
                let elapsedTime = endTime.timeIntervalSince(startTime)
                totalTimes.append(elapsedTime)
                
                // End GPU performance tracking if available
                #if os(macOS) || os(iOS)
                if #available(macOS 10.15, iOS 14.0, *) {
                    if metalPerformanceTracking,
                       let commandQueue = metalDevice?.makeCommandQueue(),
                       let sampleBuffer = metalCounterSampleBuffer,
                       let commandBuffer = commandQueue.makeCommandBuffer() {
                        
                        commandBuffer.sampleCounters(sampleBuffer, sampleIndex: 1, barrier: true)
                        commandBuffer.commit()
                        commandBuffer.waitUntilCompleted()
                        
                        // Read GPU time
                        if let counters = readMetalCounters(),
                           let gpuTimeMs = counters["gpuTimeMs"] {
                            gpuTimes.append(gpuTimeMs / 1000.0) // Convert to seconds
                        }
                    }
                }
                #endif
                
                // Record memory after
                let memoryAfter = getMemoryUsage()
                let memoryUsed = memoryAfter - memoryBefore
                memoryUsages.append(memoryUsed)
                
                // Print statistics for this iteration
                print("    ↳ Time: \(String(format: "%.2f", elapsedTime * 1000))ms, Memory: \(formatBytes(memoryUsed))")
            }
            
            // Run teardown if provided
            teardown?()
        }
        
        // Calculate average metrics
        let avgTotalTime = totalTimes.reduce(0, +) / Double(iterations)
        let avgMemoryUsage = memoryUsages.reduce(0, +) / Int64(iterations)
        let avgGpuTime = gpuTimes.isEmpty ? nil : gpuTimes.reduce(0, +) / Double(gpuTimes.count)
        
        // Print summary
        print("📈 Performance summary for '\(name)':")
        print("  ▹ Average time: \(String(format: "%.2f", avgTotalTime * 1000))ms")
        print("  ▹ Average memory: \(formatBytes(avgMemoryUsage))")
        if let avgGpuTime = avgGpuTime {
            print("  ▹ Average GPU time: \(String(format: "%.2f", avgGpuTime * 1000))ms")
        }
        
        // Create and return metrics
        return HDRPerformanceMetrics(
            totalTime: avgTotalTime,
            memoryUsage: avgMemoryUsage,
            gpuTime: avgGpuTime,
            stageMetrics: [:],  // No stage metrics for simple measurement
            metalCounters: nil  // No detailed counters for simple measurement
        )
    }
    
    /// Measure the performance of a multi-stage HDR processing pipeline
    /// - Parameters:
    ///   - name: Name of the pipeline (for reporting)
    ///   - iterations: Number of iterations to run
    ///   - setup: Optional setup closure to run before each iteration
    ///   - teardown: Optional teardown closure to run after each iteration
    ///   - stages: Dictionary of stage names and operations
    /// - Returns: Performance metrics
    public func measureHDRPipeline(
        name: String,
        iterations: Int = 5,
        setup: (() -> Void)? = nil,
        teardown: (() -> Void)? = nil,
        stages: [String: () -> Void]
    ) -> HDRPerformanceMetrics {
        print("📊 Measuring HDR pipeline '\(name)' (\(iterations) iterations)...")
        
        // Create metrics
        var totalTimes: [TimeInterval] = []
        var memoryUsages: [Int64] = []
        var gpuTimes: [TimeInterval] = []
        var stageMetrics: [String: [HDRPerformanceMetrics.StageMetric]] = [:]
        
        // Initialize stage metrics arrays
        for stageName in stages.keys {
            stageMetrics[stageName] = []
        }
        
        // Run the pipeline multiple times
        for i in 1...iterations {
            print("  ▹ Iteration \(i)/\(iterations)...")
            
            // Run setup if provided
            setup?()
            
            // Create autorelease pool for better memory management
            autoreleasepool {
                // Record memory before
                let memoryBefore = getMemoryUsage()
                
                // Start GPU performance tracking if available
                #if os(macOS) || os(iOS)
                if #available(macOS 10.15, iOS 14.0, *) {
                    if metalPerformanceTracking,
                       let commandQueue = metalDevice?.makeCommandQueue(),
                       let sampleBuffer = metalCounterSampleBuffer,
                       let commandBuffer = commandQueue.makeCommandBuffer() {
                        
                        commandBuffer.sampleCounters(sampleBuffer, sampleIndex: 0, barrier: true)
                        commandBuffer.commit()
                    }
                }
                #endif
                
                // Measure total time
                let startTime = Date()
                
                // Run each stage
                for (stageName, stageOperation) in stages {
                    print("    ▹ Running stage: \(stageName)...")
                    
                    // Measure stage
                    let stageStartTime = Date()
                    let stageMemoryBefore = getMemoryUsage()
                    
                    // Run the stage operation
                    stageOperation()
                    
                    // Calculate stage metrics
                    let stageEndTime = Date()
                    let stageElapsedTime = stageEndTime.timeIntervalSince(stageStartTime)
                    let stageMemoryAfter = getMemoryUsage()
                    let stageMemoryUsed = stageMemoryAfter - stageMemoryBefore
                    
                    // Create stage metric
                    let stageMetric = HDRPerformanceMetrics.StageMetric(
                        name: stageName,
                        processingTime: stageElapsedTime,
                        memoryUsage: stageMemoryUsed
                    )
                    
                    // Add to metrics
                    stageMetrics[stageName]?.append(stageMetric)
                    
                    // Print stage statistics
                    print("      ↳ Time: \(String(format: "%.2f", stageElapsedTime * 1000))ms, Memory: \(formatBytes(stageMemoryUsed))")
                }
                
                // End time measurement
                let endTime = Date()
                let elapsedTime = endTime.timeIntervalSince(startTime)
                totalTimes.append(elapsedTime)
                
                // End GPU performance tracking if available
                #if os(macOS) || os(iOS)
                if #available(macOS 10.15, iOS 14.0, *) {
                    if metalPerformanceTracking,
                       let commandQueue = metalDevice?.makeCommandQueue(),
                       let sampleBuffer = metalCounterSampleBuffer,
                       let commandBuffer = commandQueue.makeCommandBuffer() {
                        
                        commandBuffer.sampleCounters(sampleBuffer, sampleIndex: 1, barrier: true)
                        commandBuffer.commit()
                        commandBuffer.waitUntilCompleted()
                        
                        // Read GPU time
                        if let counters = readMetalCounters(),
                           let gpuTimeMs = counters["gpuTimeMs"] {
                            gpuTimes.append(gpuTimeMs / 1000.0) // Convert to seconds
                        }
                    }
                }
                #endif
                
                // Record memory after
                let memoryAfter = getMemoryUsage()
                let memoryUsed = memoryAfter - memoryBefore
                memoryUsages.append(memoryUsed)
                
                // Print statistics for this iteration
                print("    ↳ Total Time: \(String(format: "%.2f", elapsedTime * 1000))ms, Memory: \(formatBytes(memoryUsed))")
            }
            
            // Run teardown if provided
            teardown?()
        }
        
        // Calculate average metrics
        let avgTotalTime = totalTimes.reduce(0, +) / Double(iterations)
        let avgMemoryUsage = memoryUsages.reduce(0, +) / Int64(iterations)
        let avgGpuTime = gpuTimes.isEmpty ? nil : gpuTimes.reduce(0, +) / Double(gpuTimes.count)
        
        // Calculate average stage metrics
        var avgStageMetrics: [String: HDRPerformanceMetrics.StageMetric] = [:]
        for (stageName, metrics) in stageMetrics {
            let avgTime = metrics.map { $0.processingTime }.reduce(0, +) / Double(iterations)
            let avgMemory = metrics.compactMap { $0.memoryUsage }.reduce(0, +) / Int64(metrics.count)
            
            avgStageMetrics[stageName] = HDRPerformanceMetrics.StageMetric(
                name: stageName,
                processingTime: avgTime,
                memoryUsage: avgMemory
            )
        }
        
        // Print summary
        print("📈 Pipeline performance summary for '\(name)':")
        print("  ▹ Average total time: \(String(format: "%.2f", avgTotalTime * 1000))ms")
        print("  ▹ Average memory: \(formatBytes(avgMemoryUsage))")
        if let avgGpuTime = avgGpuTime {
            print("  ▹ Average GPU time: \(String(format: "%.2f", avgGpuTime * 1000))ms")
        }
        
        // Print stage summaries
        print("  ▹ Stage breakdown:")
        for (stageName, metric) in avgStageMetrics.sorted(by: { $0.key < $1.key }) {
            let percentage = (metric.processingTime / avgTotalTime) * 100
            print("    ↳ \(stageName): \(String(format: "%.2f", metric.processingTime * 1000))ms (\(String(format: "%.1f", percentage))%)")
        }
        
        // Create and return metrics
        return HDRPerformanceMetrics(
            totalTime: avgTotalTime,
            memoryUsage: avgMemoryUsage,
            gpuTime: avgGpuTime,
            stageMetrics: avgStageMetrics,
            metalCounters: nil  // No detailed counters for pipeline measurement
        )
    }
    
    // MARK: - Helper Methods
    
    /// Get current memory usage
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// Format bytes to human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Extensions

extension MTLCounterSampleBufferDescriptor {
    func with(_ configure: (MTLCounterSampleBufferDescriptor) -> Void) -> MTLCounterSampleBufferDescriptor {
        configure(self)
        return self
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    /// Measure HDR processing performance
    /// - Parameters:
    ///   - name: Name of the operation (for reporting)
    ///   - iterations: Number of iterations to run
    ///   - setup: Optional setup closure to run before each iteration
    ///   - teardown: Optional teardown closure to run after each iteration
    ///   - operation: The operation to measure
    /// - Returns: Performance metrics
    public func measureHDRPerformance(
        name: String,
        iterations: Int = 10,
        setup: (() -> Void)? = nil,
        teardown: (() -> Void)? = nil,
        operation: @escaping () -> Void
    ) -> HDRPerformanceTestHelper.HDRPerformanceMetrics {
        return HDRPerformanceTestHelper.shared.measureHDRPerformance(
            name: name,
            iterations: iterations,
            setup: setup,
            teardown: teardown,
            operation: operation
        )
    }
    
    /// Measure HDR pipeline performance
    /// - Parameters:
    ///   - name: Name of the pipeline (for reporting)
    ///   - iterations: Number of iterations to run
    ///   - setup: Optional setup closure to run before each iteration
    ///   - teardown: Optional teardown closure to run after each iteration
    ///   - stages: Dictionary of stage names and operations
    /// - Returns: Performance metrics
    public func measureHDRPipeline(
        name: String,
        iterations: Int = 5,
        setup: (() -> Void)? = nil,
        teardown: (() -> Void)? = nil,
        stages: [String: () -> Void]
    ) -> HDRPerformanceTestHelper.HDRPerformanceMetrics {
        return HDRPerformanceTestHelper.shared.measureHDRPipeline(
            name: name,
            iterations: iterations,
            setup: setup,
            teardown: teardown,
            stages: stages
        )
    }
} 