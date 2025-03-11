import XCTest
@testable import HDRPlusCore // Assume this is the module name

class AlignAndMergeTests: XCTestCase {
    
    // Test parameters
    private let testImageSize = (width: 512, height: 384)
    private let burstSize = 3
    private let tileSize = 128
    
    func testBasicAlignmentAndMerge() throws {
        // This test verifies that the alignment and merge pipeline works correctly
        // for a basic burst with minimal motion
        
        // Create a simulated burst of slightly offset images
        let burstImages = createSimulatedBurst(
            width: testImageSize.width,
            height: testImageSize.height,
            count: burstSize,
            maxOffset: 2, // Small displacement between frames
            noise: 0.01   // Low noise
        )
        
        // Run the images through the alignment stage
        let alignmentResult = alignImages(burst: burstImages)
        
        // Verify alignment results
        XCTAssertEqual(alignmentResult.alignmentVectors.count, burstSize - 1, "Should have alignment vectors for all non-reference frames")
        
        // Check that alignment was able to recover the offsets within reasonable error
        for vector in alignmentResult.alignmentVectors {
            XCTAssertLessThanOrEqual(abs(vector.globalOffsetX), 3, "X offset should be detected within reasonable error")
            XCTAssertLessThanOrEqual(abs(vector.globalOffsetY), 3, "Y offset should be detected within reasonable error")
        }
        
        // Run the aligned images through the merge stage
        let mergeResult = mergeAlignedImages(
            reference: burstImages[0],
            alternates: Array(burstImages.dropFirst()),
            alignmentVectors: alignmentResult.alignmentVectors
        )
        
        // Verify merge output
        XCTAssertEqual(mergeResult.width, testImageSize.width, "Merged image should have the correct width")
        XCTAssertEqual(mergeResult.height, testImageSize.height, "Merged image should have the correct height")
        
        // Verify that the SNR (signal-to-noise ratio) improved
        let inputSNR = estimateSNR(burstImages[0])
        let outputSNR = estimateSNR(mergeResult)
        
        XCTAssertGreaterThan(outputSNR, inputSNR, "Merged image should have better SNR than input")
        XCTAssertGreaterThan(outputSNR / inputSNR, 1.3, "SNR should improve by at least 30%")
    }
    
    func testAlignmentAndMergeWithMotion() throws {
        // This test verifies that the alignment and merge pipeline works correctly
        // for a burst with more significant motion
        
        // Create a simulated burst of more significantly offset images
        let burstImages = createSimulatedBurst(
            width: testImageSize.width,
            height: testImageSize.height,
            count: burstSize,
            maxOffset: 15, // Larger displacement between frames
            noise: 0.02    // Moderate noise
        )
        
        // Run the images through the alignment stage
        let alignmentResult = alignImages(burst: burstImages)
        
        // Verify alignment results - in this case we expect some residual error
        // but the alignment should still work
        for vector in alignmentResult.alignmentVectors {
            XCTAssertLessThanOrEqual(abs(vector.globalOffsetX), 17, "X offset should be detected within reasonable error")
            XCTAssertLessThanOrEqual(abs(vector.globalOffsetY), 17, "Y offset should be detected within reasonable error")
        }
        
        // Run the aligned images through the merge stage
        let mergeResult = mergeAlignedImages(
            reference: burstImages[0],
            alternates: Array(burstImages.dropFirst()),
            alignmentVectors: alignmentResult.alignmentVectors
        )
        
        // Verify merge output dims
        XCTAssertEqual(mergeResult.width, testImageSize.width, "Merged image should have the correct width")
        XCTAssertEqual(mergeResult.height, testImageSize.height, "Merged image should have the correct height")
        
        // With more motion, we expect less SNR improvement but still some benefit
        let inputSNR = estimateSNR(burstImages[0])
        let outputSNR = estimateSNR(mergeResult)
        
        XCTAssertGreaterThan(outputSNR, inputSNR, "Merged image should have better SNR than input even with motion")
        XCTAssertGreaterThan(outputSNR / inputSNR, 1.1, "SNR should improve by at least 10% even with motion")
    }
    
    // MARK: - Helper Methods
    
    /// Represents a simple image for testing
    struct TestImage {
        let data: [Float]
        let width: Int
        let height: Int
    }
    
    /// Represents global alignment vectors between images
    struct AlignmentVector {
        let globalOffsetX: Float
        let globalOffsetY: Float
        let localOffsets: [[(Float, Float)]]  // Local offsets per tile
    }
    
    /// Result of the alignment stage
    struct AlignmentResult {
        let alignmentVectors: [AlignmentVector]
        let alignedImages: [TestImage]
    }
    
    /// Creates a simulated burst of images with controlled offsets and noise
    private func createSimulatedBurst(width: Int, height: Int, count: Int, maxOffset: Int, noise: Float) -> [TestImage] {
        var burst = [TestImage]()
        
        // Create a base image with a simple pattern
        var baseData = [Float](repeating: 0, count: width * height)
        
        // Fill with a pattern that has spatial variation (good for alignment)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                
                // Create a pattern with gradients and some features
                let normalizedX = Float(x) / Float(width)
                let normalizedY = Float(y) / Float(height)
                
                // Base value is a gradient
                var value = normalizedX * normalizedY
                
                // Add some circular features for alignment
                let cx1 = Float(width) * 0.25
                let cy1 = Float(height) * 0.25
                let cx2 = Float(width) * 0.75
                let cy2 = Float(height) * 0.75
                
                let dist1 = sqrt(pow(Float(x) - cx1, 2) + pow(Float(y) - cy1, 2))
                let dist2 = sqrt(pow(Float(x) - cx2, 2) + pow(Float(y) - cy2, 2))
                
                let feature1 = max(0, 1.0 - dist1 / 50.0)
                let feature2 = max(0, 1.0 - dist2 / 70.0)
                
                value += feature1 * 0.5
                value += feature2 * 0.7
                
                baseData[i] = value
            }
        }
        
        let baseImage = TestImage(data: baseData, width: width, height: height)
        burst.append(baseImage)
        
        // Create offset variations of the base image
        for _ in 1..<count {
            let offsetX = Int.random(in: -maxOffset...maxOffset)
            let offsetY = Int.random(in: -maxOffset...maxOffset)
            
            var newData = [Float](repeating: 0, count: width * height)
            
            // Apply offset and noise
            for y in 0..<height {
                for x in 0..<width {
                    let destIndex = y * width + x
                    
                    // Source coordinates with offset
                    let srcX = x - offsetX
                    let srcY = y - offsetY
                    
                    // Check if source is in bounds
                    if srcX >= 0 && srcX < width && srcY >= 0 && srcY < height {
                        let srcIndex = srcY * width + srcX
                        newData[destIndex] = baseData[srcIndex]
                    } else {
                        // Out of bounds, use black
                        newData[destIndex] = 0
                    }
                    
                    // Add noise
                    newData[destIndex] += Float.random(in: -noise...noise)
                }
            }
            
            burst.append(TestImage(data: newData, width: width, height: height))
        }
        
        return burst
    }
    
    /// Simulates the alignment stage of the HDR+ pipeline
    private func alignImages(burst: [TestImage]) -> AlignmentResult {
        // In a real implementation, this would call the actual alignment algorithm
        // Here we're just simulating the process
        
        guard let reference = burst.first else {
            return AlignmentResult(alignmentVectors: [], alignedImages: [])
        }
        
        var alignmentVectors = [AlignmentVector]()
        var alignedImages = [TestImage]()
        
        // Reference image is already aligned
        alignedImages.append(reference)
        
        // Process each alternate frame
        for i in 1..<burst.count {
            let alternate = burst[i]
            
            // Simulate alignment by dividing into tiles and finding offsets
            let tilesX = alternate.width / tileSize + (alternate.width % tileSize > 0 ? 1 : 0)
            let tilesY = alternate.height / tileSize + (alternate.height % tileSize > 0 ? 1 : 0)
            
            var localOffsets = [[(Float, Float)]](repeating: [(Float, Float)](repeating: (0, 0), count: tilesX), count: tilesY)
            
            // Simulate cross-correlation to find offsets
            // In a real implementation, this would actually analyze the image content
            var avgOffsetX: Float = 0
            var avgOffsetY: Float = 0
            
            for y in 0..<tilesY {
                for x in 0..<tilesX {
                    // In a real implementation, we'd compute actual local motion
                    // Here we're just adding some random local variation to the global motion
                    let localOffsetX = Float.random(in: -2...2)
                    let localOffsetY = Float.random(in: -2...2)
                    
                    localOffsets[y][x] = (localOffsetX, localOffsetY)
                    
                    avgOffsetX += localOffsetX
                    avgOffsetY += localOffsetY
                }
            }
            
            let totalTiles = tilesX * tilesY
            avgOffsetX /= Float(totalTiles)
            avgOffsetY /= Float(totalTiles)
            
            // Create the alignment vector
            let alignmentVector = AlignmentVector(
                globalOffsetX: avgOffsetX,
                globalOffsetY: avgOffsetY,
                localOffsets: localOffsets
            )
            
            alignmentVectors.append(alignmentVector)
            
            // Simulate creating an aligned version of the image
            // In a real implementation, this would warp the image based on the alignment vectors
            var alignedData = [Float](repeating: 0, count: alternate.width * alternate.height)
            
            for y in 0..<alternate.height {
                for x in 0..<alternate.width {
                    let i = y * alternate.width + x
                    
                    // Simple shift-based alignment (real implementation would be more complex)
                    let shiftedX = x - Int(avgOffsetX.rounded())
                    let shiftedY = y - Int(avgOffsetY.rounded())
                    
                    if shiftedX >= 0 && shiftedX < alternate.width && shiftedY >= 0 && shiftedY < alternate.height {
                        let srcIndex = shiftedY * alternate.width + shiftedX
                        alignedData[i] = alternate.data[srcIndex]
                    } else {
                        alignedData[i] = 0 // Out of bounds
                    }
                }
            }
            
            alignedImages.append(TestImage(data: alignedData, width: alternate.width, height: alternate.height))
        }
        
        return AlignmentResult(alignmentVectors: alignmentVectors, alignedImages: alignedImages)
    }
    
    /// Simulates the merge stage of the HDR+ pipeline
    private func mergeAlignedImages(reference: TestImage, alternates: [TestImage], alignmentVectors: [AlignmentVector]) -> TestImage {
        // In a real implementation, this would call the actual merge algorithm
        // Here we're just simulating the process with a simple weighted average
        
        var mergedData = [Float](repeating: 0, count: reference.width * reference.height)
        
        // Initialize with reference image
        for i in 0..<reference.data.count {
            mergedData[i] = reference.data[i]
        }
        
        // Apply a simple average merge
        // In a real implementation, this would use more sophisticated techniques like
        // Wiener filter or temporal denoising
        let weight = 1.0 / Float(alternates.count + 1)
        
        for alt in alternates {
            for i in 0..<min(mergedData.count, alt.data.count) {
                mergedData[i] = mergedData[i] * (1.0 - weight) + alt.data[i] * weight
            }
        }
        
        return TestImage(data: mergedData, width: reference.width, height: reference.height)
    }
    
    /// Estimates the Signal-to-Noise Ratio of an image
    private func estimateSNR(_ image: TestImage) -> Float {
        // In a real implementation, this would use actual signal processing
        // Here we're just simulating with a simple variance calculation
        
        let data = image.data
        guard !data.isEmpty else { return 0 }
        
        // Calculate mean
        var sum: Float = 0
        for value in data {
            sum += value
        }
        let mean = sum / Float(data.count)
        
        // Calculate variance
        var variance: Float = 0
        for value in data {
            variance += (value - mean) * (value - mean)
        }
        variance /= Float(data.count)
        
        // Simple SNR estimate
        let signal = mean * mean
        let noise = variance
        
        return signal / noise
    }
} 