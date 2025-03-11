import XCTest
@testable import HDRPlus

class ParameterizedTestExample: XCTestCase {
    
    // MARK: - Simple Parameterized Tests
    
    func testWithMultipleImageSizes() {
        // Run the same test with different image sizes
        let sizes = [(width: 32, height: 32),
                     (width: 64, height: 64),
                     (width: 128, height: 128),
                     (width: 256, height: 256)]
        
        runParameterized(name: "Image Processing", parameters: sizes) { size, testName in
            // This closure runs once for each size
            let (width, height) = size
            
            // Simulate processing an image of this size
            let result = simulateImageProcessing(width: width, height: height)
            
            // Verify the result
            XCTAssertEqual(result.width, width, "\(testName): Width should match")
            XCTAssertEqual(result.height, height, "\(testName): Height should match")
            XCTAssertTrue(result.success, "\(testName): Processing should succeed")
        }
    }
    
    func testWithNamedParameters() {
        // Run the same test with different named parameters
        let exposureSettings: [String: Double] = [
            "underexposed": 0.5,
            "normal": 1.0,
            "overexposed": 2.0,
            "extreme_high": 4.0
        ]
        
        runParameterized(name: "Exposure Correction", parameters: exposureSettings) { exposureFactor, testName in
            // This closure runs once for each exposure setting
            let result = simulateExposureCorrection(factor: exposureFactor)
            
            // Check that the result has the correct exposure factor
            XCTAssertEqual(result.appliedFactor, exposureFactor, accuracy: 0.01, "\(testName): Applied factor should match input")
            
            // Different validity checks based on exposure level
            if exposureFactor > 3.0 {
                XCTAssertTrue(result.hasHighlightClipping, "\(testName): High exposures should have highlight clipping")
            } else if exposureFactor < 0.7 {
                XCTAssertTrue(result.hasNoisyDarkAreas, "\(testName): Low exposures should have noisy dark areas")
            }
        }
    }
    
    // MARK: - Data-Driven Tests
    
    func testColorConversion() {
        // Test RGB to HSV conversion with known input-output pairs
        let testData: [(input: (r: Double, g: Double, b: Double), expected: (h: Double, s: Double, v: Double))] = [
            (input: (r: 1.0, g: 0.0, b: 0.0), expected: (h: 0.0, s: 1.0, v: 1.0)),     // Red
            (input: (r: 0.0, g: 1.0, b: 0.0), expected: (h: 120.0, s: 1.0, v: 1.0)),   // Green
            (input: (r: 0.0, g: 0.0, b: 1.0), expected: (h: 240.0, s: 1.0, v: 1.0)),   // Blue
            (input: (r: 1.0, g: 1.0, b: 1.0), expected: (h: 0.0, s: 0.0, v: 1.0)),     // White
            (input: (r: 0.0, g: 0.0, b: 0.0), expected: (h: 0.0, s: 0.0, v: 0.0))      // Black
        ]
        
        runDataDriven(name: "RGB to HSV", data: testData) { input, expected, testName in
            // Convert RGB to HSV
            let result = simulateRGBtoHSV(r: input.r, g: input.g, b: input.b)
            
            // Verify results (with small tolerance for floating-point precision)
            XCTAssertEqual(result.h, expected.h, accuracy: 0.01, "\(testName): Hue should match")
            XCTAssertEqual(result.s, expected.s, accuracy: 0.01, "\(testName): Saturation should match")
            XCTAssertEqual(result.v, expected.v, accuracy: 0.01, "\(testName): Value should match")
        }
    }
    
    func testParameterCombinations() {
        // Test all combinations of parameters
        let apertures = [2.8, 4.0, 5.6, 8.0]
        let shutterSpeeds = [1.0/500, 1.0/250, 1.0/125, 1.0/60]
        let isoValues = [100.0, 400.0, 1600.0]
        
        // Generate all combinations
        let combinations = ParameterizedTestUtility.combinations(of: [apertures, shutterSpeeds, isoValues])
        
        // Create tuple array from combinations
        let exposureSettings = combinations.map { combo -> (aperture: Double, shutterSpeed: Double, iso: Double) in
            return (aperture: combo[0], shutterSpeed: combo[1], iso: combo[2])
        }
        
        runParameterized(name: "Exposure Calculation", parameters: exposureSettings) { settings, testName in
            let (aperture, shutterSpeed, iso) = settings
            
            // Calculate EV (Exposure Value)
            let ev = simulateCalculateEV(aperture: aperture, shutterSpeed: shutterSpeed, iso: iso)
            
            // Simple verification (just checking the function runs without errors)
            XCTAssertNotNil(ev, "\(testName): Should calculate an exposure value")
        }
    }
    
    // MARK: - Test with Parameter Ranges
    
    func testPerformanceWithVaryingImageSizes() {
        // Test with a range of image sizes
        let widths = ParameterizedTestUtility.range(from: 100, to: 500, step: 100)
        let heights = ParameterizedTestUtility.range(from: 100, to: 500, step: 100)
        
        // Create size pairs
        let sizes = widths.flatMap { width in
            heights.map { height in
                return (width: width, height: height)
            }
        }
        
        runParameterized(name: "Performance Scaling", parameters: sizes) { size, testName in
            let (width, height) = size
            
            // Measure processing time
            let executionMetric = PerformanceTestUtility.measureExecutionTime(
                name: "Process \(width)x\(height)"
            ) {
                // Simulate image processing
                _ = simulateImageProcessing(width: width, height: height)
            }
            
            // Verify that processing time scales reasonably with image size
            // (This is a simplified check - in reality you might want more complex verification)
            let pixelCount = width * height
            let timePerPixel = executionMetric.value / Double(pixelCount)
            
            // Print the metric for analysis
            print("\(testName): Time per pixel: \(timePerPixel) ms/pixel")
            
            // Very basic verification - just check that time per pixel isn't wildly increasing
            // with larger images (which might indicate poor scaling)
            XCTAssertLessThan(timePerPixel, 0.001, "\(testName): Time per pixel should be reasonable")
        }
    }
    
    // MARK: - Simulation Methods
    
    // These are stub implementations that would be replaced with actual logic
    // in a real test suite
    
    private func simulateImageProcessing(width: Int, height: Int) -> (width: Int, height: Int, success: Bool) {
        // Simulate some processing delay based on image size
        usleep(UInt32(width * height / 10000))
        return (width: width, height: height, success: true)
    }
    
    private func simulateExposureCorrection(factor: Double) -> (appliedFactor: Double, hasHighlightClipping: Bool, hasNoisyDarkAreas: Bool) {
        return (
            appliedFactor: factor,
            hasHighlightClipping: factor > 3.0,
            hasNoisyDarkAreas: factor < 0.7
        )
    }
    
    private func simulateRGBtoHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        // Simplified RGB to HSV conversion
        let maxValue = max(r, max(g, b))
        let minValue = min(r, min(g, b))
        let delta = maxValue - minValue
        
        var hue: Double = 0
        
        if delta != 0 {
            if maxValue == r {
                hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == g {
                hue = 60 * ((b - r) / delta + 2)
            } else {
                hue = 60 * ((r - g) / delta + 4)
            }
            
            if hue < 0 {
                hue += 360
            }
        }
        
        let saturation = maxValue == 0 ? 0 : delta / maxValue
        let value = maxValue
        
        return (h: hue, s: saturation, v: value)
    }
    
    private func simulateCalculateEV(aperture: Double, shutterSpeed: Double, iso: Double) -> Double? {
        // EV calculation (at ISO 100): EV = log2(aperture² / shutterSpeed)
        // Then adjust for actual ISO: EV_actual = EV_100 + log2(ISO/100)
        
        let ev100 = log2(pow(aperture, 2) / shutterSpeed)
        let evActual = ev100 + log2(iso/100)
        
        return evActual
    }
} 