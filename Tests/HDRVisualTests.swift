import XCTest
import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#endif

@available(macOS 10.15, *)
class HDRVisualTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Temporary directory for tests
    var tempDir: URL!
    
    /// Test resource bundle
    var testBundle: Bundle!
    
    /// Example bracketed images for testing
    var bracketedImages: [CGImage] = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Skip tests if running in CI and Metal tests are disabled
        try XCTSkipIf(TestConfig.shared.skipMetalTests && TestConfig.shared.isRunningInCI,
                     "Skipping Metal tests in CI")
        
        // Create temporary directory
        tempDir = try TestHelper.createTemporaryDirectory()
        
        // Get the test bundle
        testBundle = Bundle(for: type(of: self))
        
        // Load test images
        try loadTestImages()
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        try TestHelper.removeItem(at: tempDir)
        
        // Release images
        bracketedImages = []
        
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    /// Load test images
    private func loadTestImages() throws {
        // Load bracketed images
        for i in 1...3 {
            guard let url = testBundle.url(forResource: "bracket_\(i)", withExtension: "jpg", subdirectory: "TestImages"),
                  let image = loadImage(from: url) else {
                XCTFail("Failed to load test image bracket_\(i).jpg")
                continue
            }
            
            bracketedImages.append(image)
        }
        
        // Ensure we have at least 3 images
        XCTAssertGreaterThanOrEqual(bracketedImages.count, 3, "Not enough test images loaded")
    }
    
    /// Load an image from a URL
    private func loadImage(from url: URL) -> CGImage? {
        #if os(macOS)
        if let nsImage = NSImage(contentsOf: url) {
            var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
            return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        }
        #elseif os(iOS)
        if let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage.cgImage
        }
        #endif
        return nil
    }
    
    /// Process HDR images (simulating the actual HDR+ algorithm)
    /// - Returns: Processed HDR image
    private func processHDRImages() -> CGImage? {
        // This is a placeholder for the real HDR+ algorithm
        // For testing purposes, we'll create a simple composite image
        
        guard let firstImage = bracketedImages.first else {
            return nil
        }
        
        let width = firstImage.width
        let height = firstImage.height
        
        #if os(macOS)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        // Simulate HDR processing by blending the bracketed images
        // In a real implementation, this would be more sophisticated
        for (i, image) in bracketedImages.enumerated() {
            let alpha = 1.0 / Double(bracketedImages.count)
            context.setAlpha(alpha)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        return context.makeImage()
        #else
        return nil
        #endif
    }
    
    // MARK: - Tests
    
    /// Test basic HDR processing with visual comparison
    func testBasicHDRProcessing() throws {
        #if os(macOS)
        // Process HDR images
        guard let processedImage = processHDRImages() else {
            XCTFail("Failed to process HDR images")
            return
        }
        
        // Verify the result matches the reference image
        try assertHDRImage(
            processedImage,
            matchesReferenceNamed: "basic_hdr_result"
        )
        #else
        throw XCTSkip("Test only available on macOS")
        #endif
    }
    
    /// Test HDR processing with visualization
    func testHDRProcessingWithVisualization() throws {
        #if os(macOS)
        // Skip in CI to avoid test pollution
        try XCTSkipIf(TestConfig.shared.isRunningInCI, "Skipping visualization test in CI")
        
        // Process HDR images
        guard let processedImage = processHDRImages() else {
            XCTFail("Failed to process HDR images")
            return
        }
        
        // Generate visualization
        let metadata: [String: Any] = [
            "processingVersion": "1.0",
            "bracketCount": bracketedImages.count,
            "imageSize": "\(processedImage.width)x\(processedImage.height)",
            "colorSpace": processedImage.colorSpace?.name ?? "unknown"
        ]
        
        let visualizationURL = try generateHDRVisualization(
            inputImages: bracketedImages,
            outputImage: processedImage,
            metadata: metadata,
            options: .default
        )
        
        // Just verify the visualization was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: visualizationURL.path))
        #else
        throw XCTSkip("Test only available on macOS")
        #endif
    }
    
    /// Test HDR processing performance
    func testHDRProcessingPerformance() throws {
        #if os(macOS)
        // Measure performance
        let metrics = measureHDRPerformance(
            name: "Basic HDR Processing",
            iterations: 5
        ) {
            _ = self.processHDRImages()
        }
        
        // Verify performance is acceptable
        XCTAssertLessThan(metrics.totalTime, 0.5, "HDR processing should take less than 500ms")
        
        // Log performance results
        print("HDR Processing Performance:")
        print("  - Total time: \(String(format: "%.2f", metrics.totalTime * 1000))ms")
        print("  - Memory usage: \(metrics.memoryUsage / 1024 / 1024)MB")
        if let gpuTime = metrics.gpuTime {
            print("  - GPU time: \(String(format: "%.2f", gpuTime * 1000))ms")
        }
        #else
        throw XCTSkip("Test only available on macOS")
        #endif
    }
    
    /// Test HDR processing with pipeline stages
    func testHDRProcessingPipeline() throws {
        #if os(macOS)
        // Define pipeline stages
        let stages: [String: () -> Void] = [
            "Alignment": {
                // Simulate alignment stage
                Thread.sleep(forTimeInterval: 0.05)
            },
            "Merging": {
                // Simulate merging stage
                Thread.sleep(forTimeInterval: 0.1)
            },
            "ToneMapping": {
                // Simulate tone mapping stage
                Thread.sleep(forTimeInterval: 0.07)
            },
            "Finishing": {
                // Simulate finishing stage
                Thread.sleep(forTimeInterval: 0.03)
            }
        ]
        
        // Measure pipeline performance
        let metrics = measureHDRPipeline(
            name: "HDR Processing Pipeline",
            iterations: 3,
            stages: stages
        )
        
        // Verify pipeline performance is acceptable
        XCTAssertLessThan(metrics.totalTime, 0.5, "HDR pipeline should take less than 500ms")
        
        // Verify individual stages
        XCTAssertLessThan(
            metrics.stageMetrics["Alignment"]?.processingTime ?? 1.0,
            0.1,
            "Alignment stage should take less than 100ms"
        )
        
        XCTAssertLessThan(
            metrics.stageMetrics["Merging"]?.processingTime ?? 1.0,
            0.2,
            "Merging stage should take less than 200ms"
        )
        
        // Log pipeline results
        print("HDR Pipeline Performance:")
        print("  - Total time: \(String(format: "%.2f", metrics.totalTime * 1000))ms")
        
        // Log stage breakdown
        for (stageName, metric) in metrics.stageMetrics.sorted(by: { $0.key < $1.key }) {
            let percentage = (metric.processingTime / metrics.totalTime) * 100
            print("    - \(stageName): \(String(format: "%.2f", metric.processingTime * 1000))ms (\(String(format: "%.1f", percentage))%)")
        }
        #else
        throw XCTSkip("Test only available on macOS")
        #endif
    }
} 