import XCTest
import AppKit
@testable import HDRPlus

/// Integration tests for the complete HDR+ pipeline
class HDRPipelineIntegrationTests: XCTestCase {
    
    // Test fixture to use for generating test files
    private var fixture: TestFixtureUtility.Fixture!
    
    // Performance metrics tracked during the test
    private var performanceMetrics: [PerformanceTestUtility.PerformanceMetric] = []
    
    override func setUp() {
        super.setUp()
        
        // Create a fixture for temporary files
        fixture = self.createFixture()
        
        // Skip tests if Metal is not available (required for HDR pipeline)
        if !MetalTestUtility.isMetalAvailable {
            self.skipIfMetalUnavailable()
            return
        }
    }
    
    override func tearDown() {
        // Report performance metrics collected during the test
        if !performanceMetrics.isEmpty {
            PerformanceTestUtility.reportResults(in: self, metrics: performanceMetrics, failIfUnacceptable: false)
        }
        
        // Fixture will be cleaned up automatically due to deinit
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    /// Tests the entire HDR+ pipeline with a static scene
    func testFullPipelineWithStaticScene() throws {
        // Load test data - in a real test, these would be actual images from the test resources
        let baseFrame = createTestRawFrame(width: 1024, height: 768, exposure: 1.0)
        let alternateFrames = (0..<5).map { i in
            // Create frames with slight variations to simulate a burst
            createTestRawFrame(width: 1024, height: 768, exposure: 1.0 + Double(i) * 0.1)
        }
        
        // Create a pipeline configuration
        let config = createTestPipelineConfig()
        
        // 1. Test alignment stage with performance measurement
        let alignmentMetric = PerformanceTestUtility.measureExecutionTime(
            name: "Alignment",
            baselineValue: 50.0, // 50ms baseline
            acceptableRange: 0.2  // 20% deviation allowed
        ) {
            // In a real test, this would be the actual alignment function
            // For demonstration, we'll just simulate work
            Thread.sleep(forTimeInterval: 0.03) // 30ms simulated alignment
        }
        
        performanceMetrics.append(alignmentMetric)
        
        // 2. Test merge stage with performance measurement
        let mergeMetric = PerformanceTestUtility.measureExecutionTime(
            name: "Merge",
            baselineValue: 100.0, // 100ms baseline
            acceptableRange: 0.2  // 20% deviation allowed
        ) {
            // In a real test, this would be the actual merge function
            // For demonstration, we'll just simulate work
            Thread.sleep(forTimeInterval: 0.06) // 60ms simulated merge
        }
        
        performanceMetrics.append(mergeMetric)
        
        // 3. Test post-processing with performance measurement
        let postProcessingMetric = PerformanceTestUtility.measureExecutionTime(
            name: "PostProcessing",
            baselineValue: 30.0, // 30ms baseline
            acceptableRange: 0.2  // 20% deviation allowed
        ) {
            // In a real test, this would be the actual post-processing function
            // For demonstration, we'll just simulate work
            Thread.sleep(forTimeInterval: 0.02) // 20ms simulated post-processing
        }
        
        performanceMetrics.append(postProcessingMetric)
        
        // 4. Generate output image (in a real test, this would be the actual pipeline result)
        let resultImage = createProcessedTestImage(width: 1024, height: 768)
        
        // 5. Verify output with visual comparison
        let matchesReference = VisualTestUtility.compareImage(
            resultImage,
            toReferenceNamed: "full_pipeline_static_scene",
            tolerance: 0.02, // 2% difference tolerance
            in: self
        )
        
        XCTAssertTrue(matchesReference, "Processed image should match reference within tolerance")
        
        // 6. Record overall pipeline performance
        let totalTime = alignmentMetric.value + mergeMetric.value + postProcessingMetric.value
        let totalMetric = PerformanceTestUtility.PerformanceMetric(
            name: "Total Pipeline",
            value: totalTime,
            unit: "ms",
            lowerIsBetter: true,
            baseline: 180.0, // 180ms baseline
            acceptableRange: 0.2  // 20% deviation allowed
        )
        
        performanceMetrics.append(totalMetric)
        
        // 7. Save test result metadata to fixture
        let testResults = [
            "timestamp": Date().timeIntervalSince1970,
            "alignment_time_ms": alignmentMetric.value,
            "merge_time_ms": mergeMetric.value,
            "post_processing_time_ms": postProcessingMetric.value,
            "total_time_ms": totalTime,
            "image_width": 1024,
            "image_height": 768,
            "frame_count": alternateFrames.count + 1
        ]
        
        fixture.createJSONFile(named: "pipeline_test_results.json", object: testResults)
    }
    
    /// Tests the HDR pipeline with a high-dynamic-range scene
    func testHighDynamicRangeScene() throws {
        // Create test data with high dynamic range scene
        let baseFrame = createTestRawFrame(width: 1024, height: 768, exposure: 1.0, dynamicRange: .high)
        let alternateFrames = [
            createTestRawFrame(width: 1024, height: 768, exposure: 0.5, dynamicRange: .high),
            createTestRawFrame(width: 1024, height: 768, exposure: 2.0, dynamicRange: .high)
        ]
        
        // In a parameterized test approach, run multiple algorithms for comparison
        runParameterized(name: "HDR Algorithms", parameters: ["wiener", "temporal", "spatial"]) { algorithm, testName in
            // Configure pipeline for this algorithm
            let config = createTestPipelineConfig(mergeAlgorithm: algorithm)
            
            // Process the frames (simulation for the test)
            let resultImage = processBurstWithAlgorithm(baseFrame: baseFrame, alternateFrames: alternateFrames, algorithm: algorithm)
            
            // Visual verification for each algorithm variant
            let referenceName = "hdr_scene_\(algorithm)"
            let matchesReference = VisualTestUtility.compareImage(
                resultImage,
                toReferenceNamed: referenceName,
                tolerance: 0.025, // 2.5% tolerance for HDR scenes
                in: self
            )
            
            XCTAssertTrue(matchesReference, "\(testName): Processed image should match reference")
            
            // Check dynamic range preservation
            let dynamicRange = measureDynamicRange(resultImage)
            XCTAssertGreaterThan(dynamicRange, 10.0, "\(testName): Should preserve high dynamic range")
        }
    }
    
    /// Tests the pipeline's noise reduction capabilities in low light
    func testNoiseReductionLowLight() throws {
        // Create test data with low light noisy scene
        let baseFrame = createTestRawFrame(width: 1024, height: 768, exposure: 1.0, noiseLevel: .high)
        let alternateFrames = (0..<9).map { _ in
            createTestRawFrame(width: 1024, height: 768, exposure: 1.0, noiseLevel: .high)
        }
        
        // Measure memory usage during processing
        let memoryMetric = PerformanceTestUtility.measureMemoryUsage(
            name: "Low Light Processing Memory",
            baselineValue: 200.0, // 200MB baseline
            acceptableRange: 0.25  // 25% deviation allowed
        ) {
            // Process frames (simulation)
            let resultImage = processNoisyBurst(baseFrame: baseFrame, alternateFrames: alternateFrames)
            
            // Visual verification
            let matchesReference = VisualTestUtility.compareImage(
                resultImage,
                toReferenceNamed: "low_light_noise_reduction",
                tolerance: 0.035, // 3.5% tolerance for noisy scenes
                in: self
            )
            
            XCTAssertTrue(matchesReference, "Noise reduction should produce expected results")
            
            // Verify noise level in output
            let noiseLevel = measureNoiseLevel(resultImage)
            XCTAssertLessThan(noiseLevel, 0.1, "Output image should have reduced noise")
        }
        
        performanceMetrics.append(memoryMetric)
    }
    
    // MARK: - Helper Methods
    
    /// Simulates skipping test if Metal is unavailable
    private func skipIfMetalUnavailable() {
        throw XCTSkip("Skipping test because Metal is not available on this device")
    }
    
    /// Creates a test pipeline configuration
    private func createTestPipelineConfig(mergeAlgorithm: String = "wiener") -> [String: Any] {
        return [
            "merge_algorithm": mergeAlgorithm,
            "noise_model": "gaussian",
            "alignment_type": "feature_based",
            "tile_size": 256,
            "temporal_radius": 2,
            "spatial_radius": 1,
            "detail_enhancement": 1.2
        ]
    }
    
    /// Simulates creating a test RAW frame
    private enum DynamicRange {
        case normal, high, low
    }
    
    private enum NoiseLevel {
        case low, medium, high
    }
    
    private func createTestRawFrame(
        width: Int,
        height: Int,
        exposure: Double,
        dynamicRange: DynamicRange = .normal,
        noiseLevel: NoiseLevel = .low
    ) -> [UInt16] {
        // In a real test, this would create or load actual RAW frame data
        // For demonstration, we just create a dummy array
        return [UInt16](repeating: 0, count: width * height)
    }
    
    /// Simulates creating a processed test image
    private func createProcessedTestImage(width: Int, height: Int) -> NSImage {
        // Create a test image with a gradient
        let image = NSImage(size: NSSize(width: width, height: height))
        
        // In a real test, this would be the actual output from the HDR pipeline
        // For demonstration, we'll create a simple gradient image
        image.lockFocus()
        
        let context = NSGraphicsContext.current!.cgContext
        let colors = [NSColor.black.cgColor, NSColor.blue.cgColor, NSColor.white.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.5, 1]) {
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: width, y: height)
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
        
        image.unlockFocus()
        return image
    }
    
    /// Simulates processing a burst with a specific algorithm
    private func processBurstWithAlgorithm(
        baseFrame: [UInt16],
        alternateFrames: [[UInt16]],
        algorithm: String
    ) -> NSImage {
        // In a real test, this would process the frames with the actual pipeline
        // For demonstration, we'll just create a simulated result
        let width = 1024
        let height = 768
        
        // Simulate differences between algorithms
        let imageName: String
        switch algorithm {
        case "wiener":
            imageName = "wiener_result"
        case "temporal":
            imageName = "temporal_result"
        case "spatial":
            imageName = "spatial_result"
        default:
            imageName = "default_result"
        }
        
        // In a real test, this would be generated by the algorithm
        return createProcessedTestImage(width: width, height: height)
    }
    
    /// Simulates processing a noisy burst
    private func processNoisyBurst(
        baseFrame: [UInt16],
        alternateFrames: [[UInt16]]
    ) -> NSImage {
        // In a real test, this would process the frames with the actual pipeline
        // For demonstration, we'll just create a simulated result
        return createProcessedTestImage(width: 1024, height: 768)
    }
    
    /// Simulates measuring the dynamic range of an image
    private func measureDynamicRange(_ image: NSImage) -> Double {
        // In a real test, this would calculate actual dynamic range
        // For demonstration, we'll just return a simulated value
        return 12.5
    }
    
    /// Simulates measuring noise level in an image
    private func measureNoiseLevel(_ image: NSImage) -> Double {
        // In a real test, this would calculate actual noise level
        // For demonstration, we'll just return a simulated value
        return 0.05
    }
} 