import XCTest
import CoreGraphics
import CoreImage
@testable import HDRPlus

/// Integration tests for the HDR pipeline, demonstrating how to use various test utilities together.
/// These tests verify the end-to-end functionality of the HDR pipeline.
class HDRPipelineIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Test fixture for managing test resources and environment
    private var testFixture: TestFixtureUtility.Fixture!
    
    /// Mock camera for providing test frames
    private var mockCamera: MockCamera!
    
    /// The HDR pipeline under test
    private var hdrPipeline: HDRPipeline!
    
    // MARK: - Setup/Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test fixture
        testFixture = try createFixture()
        
        // Create mock camera with test data
        mockCamera = MockCamera(testFixture: testFixture)
        try prepareTestImages()
        
        // Create the HDR pipeline with the mock camera
        hdrPipeline = HDRPipeline(camera: mockCamera)
    }
    
    override func tearDown() async throws {
        // Clean up resources
        hdrPipeline = nil
        mockCamera = nil
        testFixture = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Test Cases
    
    /// Tests a basic HDR capture and processing flow with default settings.
    func testBasicHDRPipeline() throws {
        // Arrange
        let captureSettings = HDRCaptureSettings(
            frameCount: 3,
            exposureBracketStops: 2.0,
            alignmentMethod: .featureBased
        )
        
        // Act
        let result = try hdrPipeline.captureAndProcess(settings: captureSettings)
        
        // Assert
        XCTAssertNotNil(result.finalImage, "Final image should not be nil")
        XCTAssertEqual(result.sourceFrameCount, 3, "Result should include 3 source frames")
        
        // Visual verification
        if let finalImage = result.finalImage {
            try VisualTestUtility.compareImages(
                actual: finalImage,
                expected: "basic_hdr_reference",
                tolerance: 0.03,
                saveDiffOnFailure: true
            )
        }
    }
    
    /// Tests the HDR pipeline with different alignment methods.
    func testAlignmentMethods() throws {
        // Define test cases for different alignment methods
        let testCases: [(method: HDRAlignmentMethod, expectedQuality: Double)] = [
            (.featureBased, 0.9),
            (.opticalFlow, 0.85),
            (.hybrid, 0.95)
        ]
        
        // Run parameterized test for each alignment method
        try runParameterizedTest(with: testCases) { method, expectedQuality, index in
            // Arrange
            let captureSettings = HDRCaptureSettings(
                frameCount: 3,
                exposureBracketStops: 2.0,
                alignmentMethod: method
            )
            
            // Act
            let result = try self.hdrPipeline.captureAndProcess(settings: captureSettings)
            
            // Assert
            XCTAssertNotNil(result.finalImage, "Final image should not be nil")
            XCTAssertGreaterThanOrEqual(
                result.alignmentQuality ?? 0,
                expectedQuality,
                "Alignment quality should meet expectations for method \(method)"
            )
        }
    }
    
    /// Tests the HDR pipeline performance with a varying number of frames.
    func testHDRPipelinePerformance() throws {
        // Define test cases with different frame counts
        let frameCounts = [2, 3, 5, 7]
        
        // Test performance for each frame count
        for frameCount in frameCounts {
            // Arrange
            let captureSettings = HDRCaptureSettings(
                frameCount: frameCount,
                exposureBracketStops: 2.0,
                alignmentMethod: .featureBased
            )
            
            // Act & Assert - Measure execution time
            try measureExecutionTime(
                name: "hdr_pipeline_\(frameCount)_frames",
                acceptableDeviation: 0.2
            ) {
                _ = try self.hdrPipeline.captureAndProcess(settings: captureSettings)
            }
            
            // Measure memory usage
            try measureMemoryUsage(
                name: "hdr_pipeline_memory_\(frameCount)_frames",
                acceptableDeviation: 0.25
            ) {
                _ = try self.hdrPipeline.captureAndProcess(settings: captureSettings)
            }
        }
    }
    
    /// Tests the HDR pipeline with various tone mapping options.
    func testToneMappingOptions() throws {
        // Load test options from JSON
        let toneMappingOptions: [ToneMappingTestCase] = try loadTestData(
            fromJSON: "tone_mapping_test_cases"
        )
        
        // Run test for each option
        try runParameterizedTest(with: toneMappingOptions) { testCase, index in
            // Arrange
            let captureSettings = HDRCaptureSettings(
                frameCount: 3,
                exposureBracketStops: 2.0,
                alignmentMethod: .featureBased,
                toneMappingOptions: testCase.options
            )
            
            // Act
            let result = try self.hdrPipeline.captureAndProcess(settings: captureSettings)
            
            // Assert
            XCTAssertNotNil(result.finalImage, "Final image should not be nil")
            
            // Visual verification against the expected reference image
            if let finalImage = result.finalImage {
                try VisualTestUtility.compareImages(
                    actual: finalImage,
                    expected: testCase.referenceImageName,
                    tolerance: 0.04,
                    saveDiffOnFailure: true
                )
            }
        }
    }
    
    /// Tests the HDR pipeline with motion in the scene.
    func testSceneWithMotion() throws {
        // Arrange - Setup motion scene
        try mockCamera.loadMotionSequence()
        
        let captureSettings = HDRCaptureSettings(
            frameCount: 5,
            exposureBracketStops: 2.0,
            alignmentMethod: .opticalFlow,
            motionCompensation: .enabled
        )
        
        // Act
        let result = try hdrPipeline.captureAndProcess(settings: captureSettings)
        
        // Assert
        XCTAssertNotNil(result.finalImage, "Final image should not be nil")
        XCTAssertGreaterThanOrEqual(
            result.motionScore ?? 0,
            0.7,
            "Motion score should indicate motion was detected"
        )
        XCTAssertLessThanOrEqual(
            result.ghostingArtifacts ?? 0,
            0.1,
            "Ghosting artifacts should be minimal"
        )
        
        // Visual verification
        if let finalImage = result.finalImage {
            try VisualTestUtility.compareImages(
                actual: finalImage,
                expected: "motion_scene_reference",
                tolerance: 0.05, // Higher tolerance for motion scenes
                saveDiffOnFailure: true
            )
        }
    }
    
    /// Tests the error handling capabilities of the HDR pipeline.
    func testPipelineErrorHandling() throws {
        // Arrange - Configure the mock camera to generate errors
        mockCamera.simulateFrameCaptureFailed = true
        
        let captureSettings = HDRCaptureSettings(
            frameCount: 3,
            exposureBracketStops: 2.0,
            alignmentMethod: .featureBased
        )
        
        // Act & Assert - Pipeline should throw an appropriate error
        XCTAssertThrowsError(try hdrPipeline.captureAndProcess(settings: captureSettings)) { error in
            // Verify the error type
            XCTAssertTrue(
                error is HDRPipelineError,
                "Should throw HDRPipelineError"
            )
            
            // Verify the specific error
            if let hdrError = error as? HDRPipelineError {
                XCTAssertEqual(
                    hdrError, 
                    .captureError("Frame capture failed"),
                    "Should throw captureError"
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Prepares test images for the mock camera.
    private func prepareTestImages() throws {
        // Create standard test sequence
        try createExposureBracketSequence(
            baseImage: "scene1_base",
            frameCount: 7,
            stops: 1.0
        )
        
        // Create motion test sequence
        try createMotionSequence(
            baseImage: "motion_scene",
            objectOffset: CGPoint(x: 15, y: 10),
            frameCount: 5
        )
    }
    
    /// Creates an exposure bracket sequence from a base image.
    private func createExposureBracketSequence(
        baseImage: String,
        frameCount: Int,
        stops: Double
    ) throws {
        // In a real implementation, this would create actual differently-exposed images
        // For this example, we'll create simulated files in the test fixture
        
        for i in 0..<frameCount {
            let stopOffset = stops * Double(i - frameCount / 2)
            let exposureValue = pow(2.0, stopOffset)
            
            try testFixture.createFile(
                at: "frames/\(baseImage)_ev\(stopOffset).json",
                content: """
                {
                    "baseImage": "\(baseImage)",
                    "exposureValue": \(exposureValue),
                    "stopOffset": \(stopOffset),
                    "index": \(i)
                }
                """
            )
        }
    }
    
    /// Creates a sequence with simulated motion.
    private func createMotionSequence(
        baseImage: String,
        objectOffset: CGPoint,
        frameCount: Int
    ) throws {
        // In a real implementation, this would create images with simulated motion
        // For this example, we'll create simulated files in the test fixture
        
        for i in 0..<frameCount {
            let progress = Double(i) / Double(frameCount - 1)
            let currentOffset = CGPoint(
                x: objectOffset.x * progress,
                y: objectOffset.y * progress
            )
            
            try testFixture.createFile(
                at: "frames/motion/\(baseImage)_\(i).json",
                content: """
                {
                    "baseImage": "\(baseImage)",
                    "motionOffset": {
                        "x": \(currentOffset.x),
                        "y": \(currentOffset.y)
                    },
                    "index": \(i)
                }
                """
            )
        }
    }
}

// MARK: - Supporting Classes

/// Mock camera class for testing the HDR pipeline.
class MockCamera: CameraProtocol {
    private let testFixture: TestFixtureUtility.Fixture
    var simulateFrameCaptureFailed = false
    
    init(testFixture: TestFixtureUtility.Fixture) {
        self.testFixture = testFixture
    }
    
    func captureHDRBracket(
        frameCount: Int,
        exposureBracketStops: Double
    ) throws -> [CapturedFrame] {
        if simulateFrameCaptureFailed {
            throw HDRPipelineError.captureError("Frame capture failed")
        }
        
        // In a real implementation, this would return actual captured frames
        // For this example, we'll return simulated frames
        var frames: [CapturedFrame] = []
        
        for i in 0..<frameCount {
            let stopOffset = exposureBracketStops * Double(i - frameCount / 2)
            let frame = MockCapturedFrame(
                index: i,
                exposureOffset: stopOffset
            )
            frames.append(frame)
        }
        
        return frames
    }
    
    func loadMotionSequence() throws {
        // In a real implementation, this would load a sequence with motion
        // For this example, it just configures the mock to use a different sequence
    }
}

/// Mock captured frame for testing.
struct MockCapturedFrame: CapturedFrame {
    let index: Int
    let exposureOffset: Double
    
    var image: CGImage? {
        // In a real implementation, this would return an actual image
        // For this example, we return nil and assume the HDR pipeline can handle it
        return nil
    }
    
    var metadata: FrameMetadata {
        return FrameMetadata(
            exposureOffset: exposureOffset,
            iso: 100,
            shutterSpeed: 1.0 / (100.0 * pow(2.0, exposureOffset))
        )
    }
}

/// Test case for tone mapping options.
struct ToneMappingTestCase: Decodable {
    let options: ToneMappingOptions
    let referenceImageName: String
    
    enum CodingKeys: String, CodingKey {
        case options
        case referenceImageName = "reference_image"
    }
}

// MARK: - Protocol Definitions

/// Protocol for camera functionality.
protocol CameraProtocol {
    func captureHDRBracket(
        frameCount: Int,
        exposureBracketStops: Double
    ) throws -> [CapturedFrame]
}

/// Protocol for captured frames.
protocol CapturedFrame {
    var image: CGImage? { get }
    var metadata: FrameMetadata { get }
}

/// Metadata for a captured frame.
struct FrameMetadata {
    let exposureOffset: Double
    let iso: Int
    let shutterSpeed: Double
}

/// Settings for HDR capture.
struct HDRCaptureSettings {
    let frameCount: Int
    let exposureBracketStops: Double
    let alignmentMethod: HDRAlignmentMethod
    let motionCompensation: MotionCompensation = .auto
    let toneMappingOptions: ToneMappingOptions = ToneMappingOptions()
}

/// Method for aligning HDR frames.
enum HDRAlignmentMethod {
    case featureBased
    case opticalFlow
    case hybrid
}

/// Motion compensation settings.
enum MotionCompensation {
    case auto
    case enabled
    case disabled
}

/// Options for tone mapping.
struct ToneMappingOptions: Decodable {
    let method: ToneMappingMethod = .filmic
    let contrast: Double = 1.0
    let highlights: Double = 1.0
    let shadows: Double = 1.0
    let saturation: Double = 1.0
}

/// Method for tone mapping.
enum ToneMappingMethod: String, Decodable {
    case linear
    case filmic
    case reinhard
    case adaptive
}

/// Result of HDR processing.
struct HDRProcessingResult {
    let finalImage: CGImage?
    let sourceFrameCount: Int
    let alignmentQuality: Double?
    let motionScore: Double?
    let ghostingArtifacts: Double?
}

/// Errors that can occur in the HDR pipeline.
enum HDRPipelineError: Error, Equatable {
    case captureError(String)
    case alignmentError(String)
    case mergeError(String)
    case processingError(String)
}

/// The HDR pipeline that captures and processes HDR images.
class HDRPipeline {
    private let camera: CameraProtocol
    
    init(camera: CameraProtocol) {
        self.camera = camera
    }
    
    /// Captures and processes an HDR image.
    func captureAndProcess(settings: HDRCaptureSettings) throws -> HDRProcessingResult {
        // In a real implementation, this would capture and process actual frames
        // For this test example, we'll return a simulated result
        
        // Capture frames
        let frames = try camera.captureHDRBracket(
            frameCount: settings.frameCount,
            exposureBracketStops: settings.exposureBracketStops
        )
        
        // Process frames (simulate processing)
        // In a real implementation, this would do actual alignment, merging, and tone mapping
        
        return HDRProcessingResult(
            finalImage: nil, // Would be an actual image in real implementation
            sourceFrameCount: frames.count,
            alignmentQuality: getSimulatedAlignmentQuality(for: settings.alignmentMethod),
            motionScore: 0.8,
            ghostingArtifacts: 0.05
        )
    }
    
    /// Gets a simulated alignment quality for testing.
    private func getSimulatedAlignmentQuality(for method: HDRAlignmentMethod) -> Double {
        switch method {
        case .featureBased:
            return 0.92
        case .opticalFlow:
            return 0.88
        case .hybrid:
            return 0.96
        }
    }
} 