import XCTest
import CoreGraphics
import CoreImage

/// HDRToneMapVisualTests demonstrates practical visual regression testing of HDR tone mapping operations.
class HDRToneMapVisualTests: XCTestCase {
    
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
    
    // MARK: - Visual Tests
    
    /// Tests that the basic tone mapping operation produces expected results
    func testBasicToneMapping() {
        // Create a high dynamic range test image with a wider dynamic range than standard displays
        let hdrImage = createHDRGradientImage(width: 400, height: 300, maxValue: 5.0)
        
        // Apply a simple tone mapping operation to map HDR to standard display range
        let tonemappedImage = applyBasicToneMapping(to: hdrImage, gamma: 2.2)
        
        // Compare with reference image using visual test utility
        let matches = VisualTestUtility.compareImage(
            tonemappedImage,
            toReferenceNamed: "basic_tonemapped_gradient",
            tolerance: 0.02, // 2% tolerance
            in: self
        )
        
        XCTAssertTrue(matches, "Basic tone mapping result should match the reference image")
    }
    
    /// Tests that the "filmic" tone mapping operator produces expected results
    func testFilmicToneMapping() {
        // Create a high dynamic range test image with very high brightness values
        let hdrImage = createHDRGradientImage(width: 400, height: 300, maxValue: 10.0)
        
        // Apply a filmic tone mapping curve (more sophisticated than basic tone mapping)
        let tonemappedImage = applyFilmicToneMapping(to: hdrImage, exposure: 1.0)
        
        // Compare with reference image
        let matches = VisualTestUtility.compareImage(
            tonemappedImage,
            toReferenceNamed: "filmic_tonemapped_gradient",
            tolerance: 0.02, // 2% tolerance
            in: self
        )
        
        XCTAssertTrue(matches, "Filmic tone mapping result should match the reference image")
    }
    
    /// Tests tone mapping with various exposure levels
    func testExposureVariations() {
        // Create a high dynamic range test image
        let hdrImage = createHDRGradientImage(width: 400, height: 300, maxValue: 8.0)
        
        // Test different exposure values
        let exposures: [(value: Double, name: String)] = [
            (0.5, "dark"),
            (1.0, "normal"),
            (2.0, "bright")
        ]
        
        for (exposure, name) in exposures {
            // Apply tone mapping with the current exposure value
            let tonemappedImage = applyFilmicToneMapping(to: hdrImage, exposure: exposure)
            
            // Compare with reference image
            let matches = VisualTestUtility.compareImage(
                tonemappedImage,
                toReferenceNamed: "tonemapped_\(name)_exposure",
                tolerance: 0.02, // 2% tolerance
                in: self
            )
            
            XCTAssertTrue(matches, "Tone mapping with \(name) exposure should match the reference image")
        }
    }
    
    /// Tests tone mapping with various image content types
    func testContentTypeVariations() {
        // Create different types of HDR test images
        let images: [(image: CGImage, name: String)] = [
            (createHDRGradientImage(width: 400, height: 300, maxValue: 5.0), "gradient"),
            (createHDRHighlightImage(width: 400, height: 300, highlightIntensity: 8.0), "highlight"),
            (createHDRColorBarsImage(width: 400, height: 300, maxValue: 6.0), "colorbars")
        ]
        
        // Apply the same tone mapping operation to each image
        for (image, name) in images {
            let tonemappedImage = applyFilmicToneMapping(to: image, exposure: 1.0)
            
            // Compare with reference image
            let matches = VisualTestUtility.compareImage(
                tonemappedImage,
                toReferenceNamed: "tonemapped_\(name)",
                tolerance: 0.02, // 2% tolerance
                in: self
            )
            
            XCTAssertTrue(matches, "Tone mapping of \(name) image should match the reference image")
        }
    }
    
    /// Tests tone mapping parameters using parameterized testing
    func testParameterizedToneMapping() {
        // Create a high dynamic range test image
        let hdrImage = createHDRGradientImage(width: 400, height: 300, maxValue: 6.0)
        
        // Define parameter sets for tone mapping settings
        let parameterSets: [(parameters: (gamma: Double, exposure: Double), name: String)] = [
            ((gamma: 1.8, exposure: 1.0), "cinema"),
            ((gamma: 2.2, exposure: 1.0), "sRGB"),
            ((gamma: 2.4, exposure: 1.0), "HDTVGamma"),
            ((gamma: 2.2, exposure: 1.5), "brightSRGB")
        ]
        
        // Run parameterized test
        runParameterized(name: "tonemapSettings", parameterSets: parameterSets) { params, testName in
            // Apply tone mapping with the current parameters
            let (gamma, exposure) = (params.gamma, params.exposure)
            let tonemappedImage = applyCustomToneMapping(
                to: hdrImage,
                gamma: gamma,
                exposure: exposure
            )
            
            // Compare with reference image
            let matches = VisualTestUtility.compareImage(
                tonemappedImage,
                toReferenceNamed: testName,
                tolerance: 0.02, // 2% tolerance
                in: self
            )
            
            XCTAssertTrue(matches, "\(testName): Tone mapping result should match the reference image")
        }
    }
    
    // MARK: - Image Generation Methods
    
    /// Creates a high dynamic range gradient image with values exceeding standard display range
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - maxValue: The maximum brightness value (values > 1.0 are HDR)
    /// - Returns: A CGImage with high dynamic range content
    private func createHDRGradientImage(width: Int, height: Int, maxValue: Double) -> CGImage {
        let context = CIContext()
        
        // Create a gradient filter
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: CGFloat(width), y: CGFloat(height)), forKey: "inputPoint1")
        
        // Use values > 1.0 for the bright end of the gradient to simulate HDR
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: CGFloat(maxValue), green: CGFloat(maxValue), blue: CGFloat(maxValue)), forKey: "inputColor1")
        
        guard let outputImage = gradientFilter.outputImage else {
            fatalError("Failed to create gradient filter output image")
        }
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Creates a high dynamic range image with bright highlights
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - highlightIntensity: The brightness of the highlights (values > 1.0 are HDR)
    /// - Returns: A CGImage with high dynamic range highlights
    private func createHDRHighlightImage(width: Int, height: Int, highlightIntensity: Double) -> CGImage {
        let context = CIContext()
        
        // Create a dark background
        let backgroundFilter = CIFilter(name: "CIConstantColorGenerator")!
        backgroundFilter.setValue(CIColor(red: 0.1, green: 0.1, blue: 0.2), forKey: kCIInputColorKey)
        
        guard let backgroundImage = backgroundFilter.outputImage else {
            fatalError("Failed to create background filter output image")
        }
        
        // Create bright highlights using radial gradients
        let centerX = CGFloat(width) / 2
        let centerY = CGFloat(height) / 2
        
        // Create the first highlight
        let highlight1 = createRadialHighlight(
            center: CGPoint(x: centerX - CGFloat(width) * 0.2, y: centerY + CGFloat(height) * 0.1),
            radius: CGFloat(min(width, height)) * 0.15,
            intensity: highlightIntensity
        )
        
        // Create the second highlight
        let highlight2 = createRadialHighlight(
            center: CGPoint(x: centerX + CGFloat(width) * 0.25, y: centerY - CGFloat(height) * 0.15),
            radius: CGFloat(min(width, height)) * 0.1,
            intensity: highlightIntensity * 0.8
        )
        
        // Combine background and highlights
        let combinedImage = backgroundImage
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
            .composited(over: highlight1)
            .composited(over: highlight2)
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(combinedImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Creates a radial highlight for use in HDR images
    /// - Parameters:
    ///   - center: The center point of the highlight
    ///   - radius: The radius of the highlight
    ///   - intensity: The brightness of the highlight (values > 1.0 are HDR)
    /// - Returns: A CIImage with a bright highlight
    private func createRadialHighlight(center: CGPoint, radius: CGFloat, intensity: Double) -> CIImage {
        let radialFilter = CIFilter(name: "CIRadialGradient")!
        radialFilter.setValue(CIVector(cgPoint: center), forKey: "inputCenter")
        radialFilter.setValue(0.0, forKey: "inputRadius0")
        radialFilter.setValue(radius, forKey: "inputRadius1")
        
        // Create a bright center point (HDR values > 1.0)
        radialFilter.setValue(
            CIColor(red: CGFloat(intensity), green: CGFloat(intensity), blue: CGFloat(intensity * 0.8)),
            forKey: "inputColor0"
        )
        radialFilter.setValue(CIColor.clear, forKey: "inputColor1")
        
        guard let outputImage = radialFilter.outputImage else {
            fatalError("Failed to create radial gradient filter output image")
        }
        
        return outputImage
    }
    
    /// Creates a high dynamic range color bars test image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - maxValue: The maximum brightness value (values > 1.0 are HDR)
    /// - Returns: A CGImage with high dynamic range color bars
    private func createHDRColorBarsImage(width: Int, height: Int, maxValue: Double) -> CGImage {
        let context = CIContext()
        
        // Create a checkerboard as a base pattern
        let checkboardFilter = CIFilter(name: "CICheckerboardGenerator")!
        checkboardFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        checkboardFilter.setValue(CGFloat(width) / 8, forKey: "inputWidth")
        checkboardFilter.setValue(CIColor.black, forKey: "inputColor0")
        checkboardFilter.setValue(CIColor.white, forKey: "inputColor1")
        
        guard var outputImage = checkboardFilter.outputImage else {
            fatalError("Failed to create checkerboard filter output image")
        }
        
        // Add color bars with HDR brightness
        let barWidth = CGFloat(width) / 6
        let colors: [CIColor] = [
            CIColor(red: CGFloat(maxValue), green: 0, blue: 0), // Red
            CIColor(red: 0, green: CGFloat(maxValue), blue: 0), // Green
            CIColor(red: 0, green: 0, blue: CGFloat(maxValue)), // Blue
            CIColor(red: CGFloat(maxValue), green: CGFloat(maxValue), blue: 0), // Yellow
            CIColor(red: CGFloat(maxValue), green: 0, blue: CGFloat(maxValue)), // Magenta
            CIColor(red: 0, green: CGFloat(maxValue), blue: CGFloat(maxValue))  // Cyan
        ]
        
        // Create each color bar and composite it over the base image
        for (index, color) in colors.enumerated() {
            let x = CGFloat(index) * barWidth
            let barRect = CGRect(x: x, y: 0, width: barWidth, height: CGFloat(height))
            
            // Create a colored rectangle
            let colorFilter = CIFilter(name: "CIConstantColorGenerator")!
            colorFilter.setValue(color, forKey: kCIInputColorKey)
            
            guard let colorImage = colorFilter.outputImage else { continue }
            
            // Create a blend filter
            let blendFilter = CIFilter(name: "CISourceOverCompositing")!
            blendFilter.setValue(colorImage.cropped(to: barRect), forKey: kCIInputImageKey)
            blendFilter.setValue(outputImage, forKey: kCIInputBackgroundImageKey)
            
            if let blendedImage = blendFilter.outputImage {
                outputImage = blendedImage
            }
        }
        
        // Crop to the specified size
        let croppedImage = outputImage.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    // MARK: - Tone Mapping Methods
    
    /// Applies a basic tone mapping operation to an HDR image
    /// - Parameters:
    ///   - image: The HDR image to tone map
    ///   - gamma: The gamma correction value to apply
    /// - Returns: A tone mapped CGImage suitable for standard displays
    private func applyBasicToneMapping(to image: CGImage, gamma: Double) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply a simple tone mapping (using gamma adjustment for simplicity)
        let gammaFilter = CIFilter(name: "CIGammaAdjust")!
        gammaFilter.setValue(ciImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.0 / gamma, forKey: "inputPower") // Inverse gamma to compress dynamic range
        
        guard let outputImage = gammaFilter.outputImage else {
            fatalError("Failed to create gamma filter output image")
        }
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Applies a filmic tone mapping curve to an HDR image
    /// - Parameters:
    ///   - image: The HDR image to tone map
    ///   - exposure: The exposure adjustment to apply before tone mapping
    /// - Returns: A tone mapped CGImage suitable for standard displays
    private func applyFilmicToneMapping(to image: CGImage, exposure: Double) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Step 1: Apply exposure adjustment
        let exposureFilter = CIFilter(name: "CIExposureAdjust")!
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(exposure - 1.0, forKey: "inputEV") // Adjust exposure
        
        guard let exposureImage = exposureFilter.outputImage else {
            fatalError("Failed to create exposure filter output image")
        }
        
        // Step 2: Apply a custom filter that simulates a filmic curve
        // Note: For a real implementation, this would be a custom CIKernel with a filmic S-curve
        // For this example, we'll approximate with standard filters
        
        // Apply contrast enhancement
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(exposureImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: "inputContrast") // Increase contrast to create an S-curve
        
        guard let contrastImage = contrastFilter.outputImage else {
            fatalError("Failed to create contrast filter output image")
        }
        
        // Apply highlights and shadows adjustment
        let tonemapFilter = CIFilter(name: "CIHighlightShadowAdjust")!
        tonemapFilter.setValue(contrastImage, forKey: kCIInputImageKey)
        tonemapFilter.setValue(0.3, forKey: "inputHighlightAmount") // Compress highlights
        tonemapFilter.setValue(0.3, forKey: "inputShadowAmount") // Lift shadows
        
        guard let outputImage = tonemapFilter.outputImage else {
            fatalError("Failed to create tonemap filter output image")
        }
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Applies a customizable tone mapping operation to an HDR image
    /// - Parameters:
    ///   - image: The HDR image to tone map
    ///   - gamma: The gamma correction value
    ///   - exposure: The exposure adjustment
    /// - Returns: A tone mapped CGImage suitable for standard displays
    private func applyCustomToneMapping(to image: CGImage, gamma: Double, exposure: Double) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Step 1: Apply exposure adjustment
        let exposureFilter = CIFilter(name: "CIExposureAdjust")!
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(exposure - 1.0, forKey: "inputEV")
        
        guard let exposureImage = exposureFilter.outputImage else {
            fatalError("Failed to create exposure filter output image")
        }
        
        // Step 2: Apply gamma correction to compress dynamic range
        let gammaFilter = CIFilter(name: "CIGammaAdjust")!
        gammaFilter.setValue(exposureImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.0 / gamma, forKey: "inputPower")
        
        guard let gammaImage = gammaFilter.outputImage else {
            fatalError("Failed to create gamma filter output image")
        }
        
        // Step 3: Apply final color adjustments
        let colorFilter = CIFilter(name: "CIColorControls")!
        colorFilter.setValue(gammaImage, forKey: kCIInputImageKey)
        colorFilter.setValue(1.1, forKey: "inputSaturation") // Slightly increase saturation
        colorFilter.setValue(0.0, forKey: "inputBrightness") // No brightness change
        colorFilter.setValue(1.05, forKey: "inputContrast") // Slightly increase contrast
        
        guard let outputImage = colorFilter.outputImage else {
            fatalError("Failed to create color filter output image")
        }
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
} 