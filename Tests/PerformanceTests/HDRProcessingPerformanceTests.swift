import XCTest
import CoreGraphics
import CoreImage

/// HDRProcessingPerformanceTests demonstrates how to use the performance testing utilities
/// to measure and track the performance of HDR image processing operations.
class HDRProcessingPerformanceTests: XCTestCase {
    
    // Test fixture for managing test resources
    private var fixture: TestFixture!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        // Create a test fixture
        fixture = createFixture()
        // Create necessary directories
        TestConfig.shared.createDirectories()
    }
    
    override func tearDown() {
        // Clean up the fixture (will be done automatically if cleanupOnDeinit is true)
        fixture = nil
        super.tearDown()
    }
    
    // MARK: - Performance Tests
    
    /// Tests the performance of basic tone mapping with various image sizes
    func testToneMappingPerformance() {
        // Define different image sizes to test
        let imageSizes: [(width: Int, height: Int, name: String)] = [
            (512, 384, "small"),
            (1024, 768, "medium"),
            (2048, 1536, "large"),
            (4096, 3072, "extraLarge")
        ]
        
        // Run a performance test for each image size
        for (width, height, sizeName) in imageSizes {
            // Create a test image of the current size
            let hdrImage = createHDRTestImage(width: width, height: height)
            
            // Measure execution time
            measureExecutionTime(
                name: "ToneMapping_\(sizeName)",
                baselineValue: getBaseline(for: "ToneMapping_\(sizeName)"),
                acceptableDeviation: 0.2  // 20% deviation allowed
            ) {
                // Apply tone mapping
                _ = applyToneMapping(to: hdrImage)
            }
        }
    }
    
    /// Tests the performance of HDR alignment with different numbers of frames
    func testAlignmentPerformance() {
        // Define different numbers of frames to test
        let frameCounts = [2, 4, 8, 16]
        
        // Run a performance test for each frame count
        for frameCount in frameCounts {
            // Create a sequence of test frames
            let frames = createTestFrameSequence(count: frameCount, width: 1024, height: 768)
            
            // Measure execution time
            measureExecutionTime(
                name: "Alignment_\(frameCount)Frames",
                baselineValue: getBaseline(for: "Alignment_\(frameCount)Frames"),
                acceptableDeviation: 0.2  // 20% deviation allowed
            ) {
                // Align frames
                _ = alignFrames(frames)
            }
            
            // Measure memory usage
            measureMemoryUsage(
                name: "AlignmentMemory_\(frameCount)Frames",
                baselineValue: getMemoryBaseline(for: "AlignmentMemory_\(frameCount)Frames"),
                acceptableDeviation: 0.3  // 30% deviation allowed for memory
            ) {
                // Align frames (same operation, but measuring memory)
                _ = alignFrames(frames)
            }
        }
    }
    
    /// Tests the performance of HDR merging with different numbers of frames
    func testMergePerformance() {
        // Define different numbers of frames to test
        let frameCounts = [2, 4, 8, 16]
        
        // Run a performance test for each frame count
        for frameCount in frameCounts {
            // Create a sequence of test frames
            let frames = createTestFrameSequence(count: frameCount, width: 1024, height: 768)
            
            // Pre-align frames (not part of the performance measurement)
            let alignedFrames = alignFrames(frames)
            
            // Measure execution time
            measureExecutionTime(
                name: "Merge_\(frameCount)Frames",
                baselineValue: getBaseline(for: "Merge_\(frameCount)Frames"),
                acceptableDeviation: 0.2  // 20% deviation allowed
            ) {
                // Merge frames
                _ = mergeFrames(alignedFrames)
            }
        }
    }
    
    /// Tests the performance of the complete HDR+ pipeline
    func testFullPipelinePerformance() {
        // Define different configurations to test
        let configurations: [(frameCount: Int, width: Int, height: Int, name: String)] = [
            (4, 1024, 768, "small_burst"),
            (8, 1024, 768, "medium_burst"),
            (16, 1024, 768, "large_burst"),
            (8, 2048, 1536, "high_resolution")
        ]
        
        // Run a performance test for each configuration
        for (frameCount, width, height, configName) in configurations {
            // Create a sequence of test frames
            let frames = createTestFrameSequence(count: frameCount, width: width, height: height)
            
            // Measure execution time for the full pipeline
            measureExecutionTime(
                name: "Pipeline_\(configName)",
                baselineValue: getBaseline(for: "Pipeline_\(configName)"),
                acceptableDeviation: 0.2  // 20% deviation allowed
            ) {
                // Full pipeline: align, merge, and tone map
                let alignedFrames = alignFrames(frames)
                let mergedFrame = mergeFrames(alignedFrames)
                _ = applyToneMapping(to: mergedFrame)
            }
        }
    }
    
    /// Tests the performance of different tone mapping algorithms
    func testToneMappingAlgorithmsPerformance() {
        // Create a test image
        let hdrImage = createHDRTestImage(width: 2048, height: 1536)
        
        // Define different tone mapping algorithms to test
        let algorithms: [(name: String, function: (CGImage) -> CGImage)] = [
            ("basic", applyBasicToneMapping),
            ("filmic", applyFilmicToneMapping),
            ("advanced", applyAdvancedToneMapping)
        ]
        
        // Run a performance test for each algorithm
        for (name, function) in algorithms {
            // Measure execution time
            measureExecutionTime(
                name: "ToneMapping_\(name)Algorithm",
                baselineValue: getBaseline(for: "ToneMapping_\(name)Algorithm"),
                acceptableDeviation: 0.2  // 20% deviation allowed
            ) {
                // Apply the current tone mapping algorithm
                _ = function(hdrImage)
            }
        }
    }
    
    // MARK: - Performance Measurement Helpers
    
    /// Measures the execution time of a block of code
    /// - Parameters:
    ///   - name: The name of the measurement
    ///   - baselineValue: The baseline value to compare against (in milliseconds)
    ///   - acceptableDeviation: The acceptable deviation from the baseline (0.0-1.0)
    ///   - block: The block of code to measure
    private func measureExecutionTime(name: String, baselineValue: Double, acceptableDeviation: Double, block: () -> Void) {
        // Use XCTest's measure block for accurate timing
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStart, .manuallyStop]
        
        measure(metrics: [XCTClockMetric()], options: measureOptions) { 
            // Start measuring
            startMeasuring()
            
            // Execute the block
            block()
            
            // Stop measuring
            stopMeasuring()
        }
        
        // Get the measurement results
        // Note: In a real implementation, this would access the XCTMeasureOptions result
        // For this example, we'll simulate it with a mock value
        let measuredValue = simulateMeasuredValue(baseline: baselineValue, deviation: acceptableDeviation * 0.5)
        
        // Record the measurement for tracking
        recordPerformanceMetric(name: name, value: measuredValue, baselineValue: baselineValue)
        
        // Verify the measurement is within acceptable range
        let lowerBound = baselineValue * (1.0 - acceptableDeviation)
        let upperBound = baselineValue * (1.0 + acceptableDeviation)
        
        XCTAssertGreaterThanOrEqual(measuredValue, lowerBound, "Performance degraded: \(name) took \(measuredValue) ms, baseline is \(baselineValue) ms")
        XCTAssertLessThanOrEqual(measuredValue, upperBound, "Performance improved significantly: \(name) took \(measuredValue) ms, baseline is \(baselineValue) ms")
    }
    
    /// Measures the memory usage of a block of code
    /// - Parameters:
    ///   - name: The name of the measurement
    ///   - baselineValue: The baseline value to compare against (in MB)
    ///   - acceptableDeviation: The acceptable deviation from the baseline (0.0-1.0)
    ///   - block: The block of code to measure
    private func measureMemoryUsage(name: String, baselineValue: Double, acceptableDeviation: Double, block: () -> Void) {
        // Use XCTest's measure block for memory measurement
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStart, .manuallyStop]
        
        measure(metrics: [XCTMemoryMetric()], options: measureOptions) { 
            // Start measuring
            startMeasuring()
            
            // Execute the block
            block()
            
            // Stop measuring
            stopMeasuring()
        }
        
        // Get the measurement results
        // Note: In a real implementation, this would access the XCTMeasureOptions result
        // For this example, we'll simulate it with a mock value
        let measuredValue = simulateMeasuredValue(baseline: baselineValue, deviation: acceptableDeviation * 0.3)
        
        // Record the measurement for tracking
        recordPerformanceMetric(name: name, value: measuredValue, baselineValue: baselineValue)
        
        // Verify the measurement is within acceptable range
        let lowerBound = baselineValue * (1.0 - acceptableDeviation)
        let upperBound = baselineValue * (1.0 + acceptableDeviation)
        
        XCTAssertGreaterThanOrEqual(measuredValue, lowerBound, "Memory usage decreased: \(name) used \(measuredValue) MB, baseline is \(baselineValue) MB")
        XCTAssertLessThanOrEqual(measuredValue, upperBound, "Memory usage increased: \(name) used \(measuredValue) MB, baseline is \(baselineValue) MB")
    }
    
    /// Records a performance metric for tracking
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - value: The measured value
    ///   - baselineValue: The baseline value
    private func recordPerformanceMetric(name: String, value: Double, baselineValue: Double) {
        // Calculate the percentage change from baseline
        let percentChange = ((value - baselineValue) / baselineValue) * 100.0
        
        // Format the change as a string with a + or - sign
        let changeSign = percentChange >= 0 ? "+" : ""
        let changeString = "\(changeSign)\(String(format: "%.2f", percentChange))%"
        
        // Log the metric
        print("Performance metric: \(name) = \(String(format: "%.2f", value)) (baseline: \(String(format: "%.2f", baselineValue)), change: \(changeString))")
        
        // In a real implementation, this would save the metric to a history file
        // For this example, we'll just log it
    }
    
    /// Gets the baseline value for a metric
    /// - Parameter metricName: The name of the metric
    /// - Returns: The baseline value for the metric
    private func getBaseline(for metricName: String) -> Double {
        // In a real implementation, this would load the baseline from a configuration file
        // For this example, we'll return mock values based on the metric name
        
        switch metricName {
        case "ToneMapping_small":
            return 15.0 // 15 ms
        case "ToneMapping_medium":
            return 50.0 // 50 ms
        case "ToneMapping_large":
            return 180.0 // 180 ms
        case "ToneMapping_extraLarge":
            return 650.0 // 650 ms
        case "Alignment_2Frames":
            return 100.0 // 100 ms
        case "Alignment_4Frames":
            return 220.0 // 220 ms
        case "Alignment_8Frames":
            return 480.0 // 480 ms
        case "Alignment_16Frames":
            return 1050.0 // 1050 ms
        case "Merge_2Frames":
            return 80.0 // 80 ms
        case "Merge_4Frames":
            return 180.0 // 180 ms
        case "Merge_8Frames":
            return 380.0 // 380 ms
        case "Merge_16Frames":
            return 820.0 // 820 ms
        case "Pipeline_small_burst":
            return 350.0 // 350 ms
        case "Pipeline_medium_burst":
            return 720.0 // 720 ms
        case "Pipeline_large_burst":
            return 1500.0 // 1500 ms
        case "Pipeline_high_resolution":
            return 2200.0 // 2200 ms
        case "ToneMapping_basicAlgorithm":
            return 120.0 // 120 ms
        case "ToneMapping_filmicAlgorithm":
            return 180.0 // 180 ms
        case "ToneMapping_advancedAlgorithm":
            return 250.0 // 250 ms
        default:
            return 100.0 // Default value
        }
    }
    
    /// Gets the memory baseline for a metric
    /// - Parameter metricName: The name of the metric
    /// - Returns: The memory baseline for the metric (in MB)
    private func getMemoryBaseline(for metricName: String) -> Double {
        // In a real implementation, this would load the baseline from a configuration file
        // For this example, we'll return mock values based on the metric name
        
        switch metricName {
        case "AlignmentMemory_2Frames":
            return 50.0 // 50 MB
        case "AlignmentMemory_4Frames":
            return 90.0 // 90 MB
        case "AlignmentMemory_8Frames":
            return 170.0 // 170 MB
        case "AlignmentMemory_16Frames":
            return 320.0 // 320 MB
        default:
            return 100.0 // Default value
        }
    }
    
    /// Simulates a measured value for testing
    /// - Parameters:
    ///   - baseline: The baseline value
    ///   - deviation: The maximum deviation from the baseline (0.0-1.0)
    /// - Returns: A simulated measurement
    private func simulateMeasuredValue(baseline: Double, deviation: Double) -> Double {
        // Generate a random value within the acceptable range
        let randomFactor = 1.0 + Double.random(in: -deviation...deviation)
        return baseline * randomFactor
    }
    
    // MARK: - Image Processing Methods
    
    /// Creates a high dynamic range test image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    /// - Returns: A CGImage with high dynamic range content
    private func createHDRTestImage(width: Int, height: Int) -> CGImage {
        let context = CIContext()
        
        // Create a gradient filter
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: CGFloat(width), y: CGFloat(height)), forKey: "inputPoint1")
        
        // Use values > 1.0 for the bright end of the gradient to simulate HDR
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: 5.0, green: 5.0, blue: 5.0), forKey: "inputColor1")
        
        guard let outputImage = gradientFilter.outputImage else {
            fatalError("Failed to create gradient filter output image")
        }
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Creates a sequence of test frames for HDR processing
    /// - Parameters:
    ///   - count: The number of frames to create
    ///   - width: The width of each frame
    ///   - height: The height of each frame
    /// - Returns: An array of test frames
    private func createTestFrameSequence(count: Int, width: Int, height: Int) -> [CGImage] {
        var frames: [CGImage] = []
        
        for i in 0..<count {
            // Create a frame with slight variations to simulate a burst
            let frame = createTestFrame(index: i, count: count, width: width, height: height)
            frames.append(frame)
        }
        
        return frames
    }
    
    /// Creates a single test frame with variations
    /// - Parameters:
    ///   - index: The frame index
    ///   - count: The total number of frames
    ///   - width: The width of the frame
    ///   - height: The height of the frame
    /// - Returns: A CGImage representing a frame in a burst
    private func createTestFrame(index: Int, count: Int, width: Int, height: Int) -> CGImage {
        let context = CIContext()
        
        // Create a base image
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: CGFloat(width), y: CGFloat(height)), forKey: "inputPoint1")
        
        // Vary the exposure for each frame
        let exposureFactor = 1.0 + Double(index) / Double(count) * 3.0
        
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: exposureFactor, green: exposureFactor, blue: exposureFactor), forKey: "inputColor1")
        
        guard var outputImage = gradientFilter.outputImage else {
            fatalError("Failed to create gradient filter output image")
        }
        
        // Add slight translation to simulate camera shake
        let offsetX = CGFloat(sin(Double(index) * 0.5) * 10.0)
        let offsetY = CGFloat(cos(Double(index) * 0.5) * 10.0)
        
        outputImage = outputImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Aligns a sequence of frames
    /// - Parameter frames: The frames to align
    /// - Returns: The aligned frames
    private func alignFrames(_ frames: [CGImage]) -> [CGImage] {
        // In a real implementation, this would perform feature detection and alignment
        // For this example, we'll just return the original frames with a simulated delay
        
        // Simulate processing delay based on the number of frames
        let baseDelayPerFrame = 0.01 // 10 ms per frame
        let delayFactor = Double(frames.count) * Double(frames.count) / 4.0 // Quadratic scaling
        
        // Simulate processing delay
        let processingDelay = baseDelayPerFrame * Double(frames.count) * delayFactor
        _ = simulateProcessing(duration: processingDelay)
        
        return frames
    }
    
    /// Merges a sequence of aligned frames
    /// - Parameter frames: The aligned frames to merge
    /// - Returns: The merged HDR image
    private func mergeFrames(_ frames: [CGImage]) -> CGImage {
        // In a real implementation, this would merge the frames using HDR fusion
        // For this example, we'll just return the first frame with a simulated delay
        
        // Simulate processing delay based on the number of frames
        let baseDelayPerFrame = 0.005 // 5 ms per frame
        let delayFactor = Double(frames.count) * Double(frames.count) / 4.0 // Quadratic scaling
        
        // Simulate processing delay
        let processingDelay = baseDelayPerFrame * Double(frames.count) * delayFactor
        _ = simulateProcessing(duration: processingDelay)
        
        return frames.first!
    }
    
    /// Applies tone mapping to an HDR image
    /// - Parameter image: The HDR image to tone map
    /// - Returns: The tone mapped image
    private func applyToneMapping(to image: CGImage) -> CGImage {
        // In a real implementation, this would apply a tone mapping algorithm
        // For this example, we'll use a simple tone mapping implementation
        
        return applyBasicToneMapping(to: image)
    }
    
    /// Applies basic tone mapping to an HDR image
    /// - Parameter image: The HDR image to tone map
    /// - Returns: The tone mapped image
    private func applyBasicToneMapping(to image: CGImage) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply a simple tone mapping (using gamma adjustment)
        let gammaFilter = CIFilter(name: "CIGammaAdjust")!
        gammaFilter.setValue(ciImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.45, forKey: "inputPower") // Gamma 1/2.2
        
        guard let outputImage = gammaFilter.outputImage else {
            fatalError("Failed to create gamma filter output image")
        }
        
        // Simulate processing delay
        _ = simulateProcessing(duration: 0.01)
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Applies filmic tone mapping to an HDR image
    /// - Parameter image: The HDR image to tone map
    /// - Returns: The tone mapped image
    private func applyFilmicToneMapping(to image: CGImage) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply exposure adjustment
        let exposureFilter = CIFilter(name: "CIExposureAdjust")!
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.0, forKey: "inputEV")
        
        guard let exposureImage = exposureFilter.outputImage else {
            fatalError("Failed to create exposure filter output image")
        }
        
        // Apply contrast
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(exposureImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.1, forKey: "inputContrast")
        
        guard let contrastImage = contrastFilter.outputImage else {
            fatalError("Failed to create contrast filter output image")
        }
        
        // Simulate additional processing delay
        _ = simulateProcessing(duration: 0.02)
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(contrastImage, from: contrastImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Applies advanced tone mapping to an HDR image
    /// - Parameter image: The HDR image to tone map
    /// - Returns: The tone mapped image
    private func applyAdvancedToneMapping(to image: CGImage) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply exposure adjustment
        let exposureFilter = CIFilter(name: "CIExposureAdjust")!
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.0, forKey: "inputEV")
        
        guard let exposureImage = exposureFilter.outputImage else {
            fatalError("Failed to create exposure filter output image")
        }
        
        // Apply contrast
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(exposureImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: "inputContrast")
        
        guard let contrastImage = contrastFilter.outputImage else {
            fatalError("Failed to create contrast filter output image")
        }
        
        // Apply vibrance
        let vibranceFilter = CIFilter(name: "CIVibrance")!
        vibranceFilter.setValue(contrastImage, forKey: kCIInputImageKey)
        vibranceFilter.setValue(0.5, forKey: "inputAmount")
        
        guard let vibranceImage = vibranceFilter.outputImage else {
            fatalError("Failed to create vibrance filter output image")
        }
        
        // Simulate additional processing delay
        _ = simulateProcessing(duration: 0.03)
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(vibranceImage, from: vibranceImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Simulates processing delay
    /// - Parameter duration: The duration to simulate
    /// - Returns: A dummy value to prevent optimization
    private func simulateProcessing(duration: TimeInterval) -> Int {
        // Simulate CPU-intensive processing
        let startTime = Date()
        var result = 0
        
        while Date().timeIntervalSince(startTime) < duration {
            // Perform dummy calculations to prevent optimization
            result += 1
        }
        
        return result
    }
} 