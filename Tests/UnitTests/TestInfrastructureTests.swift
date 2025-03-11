import XCTest
@testable import HDRPlus

class TestInfrastructureTests: XCTestCase {
    
    // MARK: - Performance Test Utility Tests
    
    func testPerformanceMetricTracking() {
        // Test tracking execution time
        let executionMetric = PerformanceTestUtility.measureExecutionTime(
            name: "Sample Execution",
            baselineValue: 10.0,
            acceptableRange: 5.0
        ) {
            // Simulate work
            usleep(5000) // Sleep for 5ms
        }
        
        XCTAssertEqual(executionMetric.name, "Sample Execution")
        XCTAssertTrue(executionMetric.value > 0, "Should measure positive execution time")
        XCTAssertEqual(executionMetric.unit, "ms")
        XCTAssertTrue(executionMetric.lowerIsBetter)
        XCTAssertEqual(executionMetric.baseline, 10.0)
        XCTAssertEqual(executionMetric.acceptableRange, 5.0)
        
        // Test memory usage tracking
        let memoryMetric = PerformanceTestUtility.measureMemoryUsage(
            name: "Sample Memory Usage",
            baselineValue: 1.0,
            acceptableRange: 0.5
        ) {
            // Allocate some memory
            var array = [Int](repeating: 0, count: 1000000)
            // Use the array to prevent optimization
            array[0] = 1
            _ = array
        }
        
        XCTAssertEqual(memoryMetric.name, "Sample Memory Usage")
        XCTAssertTrue(memoryMetric.value >= 0, "Should measure non-negative memory usage")
        XCTAssertEqual(memoryMetric.unit, "MB")
        XCTAssertTrue(memoryMetric.lowerIsBetter)
        XCTAssertEqual(memoryMetric.baseline, 1.0)
        XCTAssertEqual(memoryMetric.acceptableRange, 0.5)
        
        // Test multiple iteration performance measurement
        PerformanceTestUtility.measurePerformance(
            name: "Multi-Iteration Test",
            iterations: 3
        ) {
            // Simulate work
            usleep(1000) // Sleep for 1ms
        }
        
        // We don't assert anything here since we're just validating it doesn't crash
    }
    
    func testPerformanceReporting() {
        // Record a test result with metrics
        let metrics = [
            PerformanceTestUtility.PerformanceMetric(
                name: "Test Metric",
                value: 15.0,
                unit: "ms",
                lowerIsBetter: true,
                baseline: 10.0,
                acceptableRange: 0.1 // 10% acceptable range
            ),
            PerformanceTestUtility.PerformanceMetric(
                name: "Acceptable Metric",
                value: 10.5,
                unit: "ms",
                lowerIsBetter: true,
                baseline: 10.0,
                acceptableRange: 0.1 // 10% acceptable range
            )
        ]
        
        // This doesn't fail the test case even if metrics are outside acceptable range
        PerformanceTestUtility.reportResults(in: self, metrics: metrics, failIfUnacceptable: false)
        
        // Test formatted values
        XCTAssertEqual(metrics[0].formattedValue, "15.00 ms")
        XCTAssertFalse(metrics[0].isAcceptable, "Should be outside acceptable range")
        XCTAssertTrue(metrics[1].isAcceptable, "Should be within acceptable range")
    }
    
    // MARK: - Metal Test Utility Tests
    
    func testMetalUtilityAvailability() {
        // We don't assert specific values here since Metal may or may not be available
        // Just test that the function runs and returns a boolean
        let _ = MetalTestUtility.isMetalAvailable
        
        // Skip if Metal is unavailable without crashing
        if !MetalTestUtility.isMetalAvailable {
            self.skipIfMetalUnavailable()
            return
        }
    }
    
    func testMetalBufferCreation() {
        // Skip if Metal is unavailable
        guard MetalTestUtility.isMetalAvailable else {
            self.skipIfMetalUnavailable()
            return
        }
        
        // Test create buffer from data
        let testData: [Float] = [1.0, 2.0, 3.0, 4.0]
        guard let buffer = MetalTestUtility.createBuffer(from: testData) else {
            XCTFail("Failed to create Metal buffer")
            return
        }
        
        // Test read buffer
        let readData = MetalTestUtility.readBuffer(buffer, as: Float.self)
        XCTAssertEqual(readData, testData, "Buffer data should match input data")
        
        // Test creating empty buffer
        let emptyBuffer = MetalTestUtility.createBuffer(size: 1024)
        XCTAssertNotNil(emptyBuffer, "Should be able to create empty buffer")
        XCTAssertEqual(emptyBuffer?.length, 1024, "Buffer length should match requested size")
        
        // Test creating zero-filled buffer
        let zeroBuffer = MetalTestUtility.createZeroFilledBuffer(elementCount: 10, elementSize: 4)
        XCTAssertNotNil(zeroBuffer, "Should be able to create zero-filled buffer")
        let zeroData = MetalTestUtility.readBuffer(zeroBuffer!, as: UInt32.self)
        XCTAssertEqual(zeroData, [UInt32](repeating: 0, count: 10), "Buffer should be filled with zeros")
    }
    
    func testMetalTestGrid() {
        // Test create grid
        let grid = MetalTestUtility.createTestGrid(width: 3, height: 2) { x, y in
            return Float(x + y * 10)
        }
        
        let expected: [Float] = [
            0.0, 1.0, 2.0,  // y=0
            10.0, 11.0, 12.0 // y=1
        ]
        
        XCTAssertEqual(grid, expected, "Grid values should match expected pattern")
    }
    
    func testArrayComparison() {
        let array1 = [1.0, 2.0, 3.0]
        let array2 = [1.1, 1.9, 3.0]
        
        // Should pass with tolerance 0.2
        let result1 = MetalTestUtility.compareArrays(
            actual: array1,
            expected: array2,
            tolerance: 0.2
        )
        XCTAssertTrue(result1, "Arrays should be equal within tolerance 0.2")
        
        // Should fail with tolerance 0.05
        let result2 = MetalTestUtility.compareArrays(
            actual: array1,
            expected: array2,
            tolerance: 0.05
        )
        XCTAssertFalse(result2, "Arrays should not be equal within tolerance 0.05")
        
        // XCTestCase extension version
        XCTAssertArrayEqual(array1, array2, tolerance: 0.2)
    }
}

// MARK: - XCTestCase Extensions for Metal Testing

extension XCTestCase {
    /// Skip test if Metal is unavailable
    func skipIfMetalUnavailable() {
        if !MetalTestUtility.isMetalAvailable {
            XCTSkip("Skipping test because Metal is not available on this device")
        }
    }
} 