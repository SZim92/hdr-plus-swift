import XCTest
import CoreGraphics
import CoreImage

/// ExampleVisualTests demonstrates how to use the VisualTestUtility for visual regression testing.
class ExampleVisualTests: XCTestCase {
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        // Create necessary directories
        TestConfig.shared.createDirectories()
    }
    
    override func tearDown() {
        // Clean up any test artifacts if needed
        super.tearDown()
    }
    
    // MARK: - Example Tests
    
    /// Test that demonstrates comparing a processed image with a reference image
    func testBasicImageComparison() {
        // Create a test image (solid red)
        let testImage = createTestImage(width: 100, height: 100, color: .red)
        
        // Compare with reference image
        let matches = VisualTestUtility.compareImage(
            testImage,
            toReferenceNamed: "solid_red",
            tolerance: 0.01, // 1% tolerance
            in: self
        )
        
        XCTAssertTrue(matches, "Image should match reference image")
    }
    
    /// Test that demonstrates checking for visual differences in processed images
    func testProcessingEffect() {
        // Create a test image (a gradient)
        let testImage = createGradientImage(width: 200, height: 200)
        
        // Apply a processing effect (e.g., blur)
        let processedImage = applyBlur(to: testImage, radius: 5.0)
        
        // Compare with reference image
        let matches = VisualTestUtility.compareImage(
            processedImage,
            toReferenceNamed: "blurred_gradient",
            tolerance: 0.05, // 5% tolerance
            in: self
        )
        
        XCTAssertTrue(matches, "Processed image should match reference image")
    }
    
    /// Test that demonstrates visual regression testing with multiple parameters
    func testMultipleParameters() {
        // Test with different blur amounts
        let blurAmounts: [(name: String, radius: Double)] = [
            ("light_blur", 2.0),
            ("medium_blur", 5.0),
            ("heavy_blur", 10.0)
        ]
        
        // Create a test image (a gradient)
        let testImage = createGradientImage(width: 200, height: 200)
        
        // Test each blur amount
        for (name, radius) in blurAmounts {
            // Apply blur
            let processedImage = applyBlur(to: testImage, radius: radius)
            
            // Compare with reference image
            let matches = VisualTestUtility.compareImage(
                processedImage,
                toReferenceNamed: "gradient_\(name)",
                tolerance: 0.05, // 5% tolerance
                in: self
            )
            
            XCTAssertTrue(matches, "Processed image with \(name) should match reference image")
        }
    }
    
    /// Test that demonstrates visual testing of tonemapping
    func testTonemapping() {
        // Create a high dynamic range test image
        let hdrImage = createHDRImage(width: 200, height: 200)
        
        // Apply tonemapping
        let tonemappedImage = applyTonemapping(to: hdrImage)
        
        // Compare with reference image
        let matches = VisualTestUtility.compareImage(
            tonemappedImage,
            toReferenceNamed: "tonemapped_hdr",
            tolerance: 0.05, // 5% tolerance
            in: self
        )
        
        XCTAssertTrue(matches, "Tonemapped image should match reference image")
    }
    
    // MARK: - Helper Methods
    
    /// Creates a solid color test image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - color: The color to fill the image with
    /// - Returns: A CGImage with the specified dimensions and color
    private func createTestImage(width: Int, height: Int, color: CIColor) -> CGImage {
        let context = CIContext()
        
        // Create a solid color image
        let colorFilter = CIFilter(name: "CIConstantColorGenerator")!
        colorFilter.setValue(color, forKey: kCIInputColorKey)
        
        guard let outputImage = colorFilter.outputImage else {
            fatalError("Failed to create color filter output image")
        }
        
        // Crop to the desired size
        let croppedImage = outputImage.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Creates a gradient test image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    /// - Returns: A CGImage with a gradient from black to white
    private func createGradientImage(width: Int, height: Int) -> CGImage {
        let context = CIContext()
        
        // Create a gradient image
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: CGFloat(width), y: CGFloat(height)), forKey: "inputPoint1")
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor.white, forKey: "inputColor1")
        
        guard let outputImage = gradientFilter.outputImage else {
            fatalError("Failed to create gradient filter output image")
        }
        
        // Crop to the desired size
        let croppedImage = outputImage.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Creates a simulated HDR image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    /// - Returns: A CGImage with high dynamic range
    private func createHDRImage(width: Int, height: Int) -> CGImage {
        let context = CIContext()
        
        // Create a gradient with bright highlights
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: CGFloat(width), y: CGFloat(height)), forKey: "inputPoint1")
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: 2.0, green: 2.0, blue: 2.0), forKey: "inputColor1") // Values > 1.0 for HDR
        
        guard let outputImage = gradientFilter.outputImage else {
            fatalError("Failed to create HDR gradient filter output image")
        }
        
        // Add some bright spots
        let radialGradientFilter = CIFilter(name: "CIRadialGradient")!
        radialGradientFilter.setValue(CIVector(x: CGFloat(width / 2), y: CGFloat(height / 2)), forKey: "inputCenter")
        radialGradientFilter.setValue(10.0, forKey: "inputRadius0")
        radialGradientFilter.setValue(CGFloat(width / 3), forKey: "inputRadius1")
        radialGradientFilter.setValue(CIColor(red: 3.0, green: 3.0, blue: 3.0), forKey: "inputColor0") // Very bright center
        radialGradientFilter.setValue(CIColor.clear, forKey: "inputColor1")
        
        guard let radialOutput = radialGradientFilter.outputImage else {
            fatalError("Failed to create radial gradient filter output image")
        }
        
        // Combine gradient and bright spots
        let addFilter = CIFilter(name: "CIAdditionCompositing")!
        addFilter.setValue(outputImage, forKey: kCIInputImageKey)
        addFilter.setValue(radialOutput, forKey: kCIInputBackgroundImageKey)
        
        guard let combinedOutput = addFilter.outputImage else {
            fatalError("Failed to create combined HDR image")
        }
        
        // Crop to the desired size
        let croppedImage = combinedOutput.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convert to CGImage
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Applies a blur effect to an image
    /// - Parameters:
    ///   - image: The image to blur
    ///   - radius: The blur radius
    /// - Returns: A blurred CGImage
    private func applyBlur(to image: CGImage, radius: Double) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply a Gaussian blur
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(radius, forKey: kCIInputRadiusKey)
        
        guard let outputImage = blurFilter.outputImage else {
            fatalError("Failed to create blur filter output image")
        }
        
        // Convert back to CGImage
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        return cgImage
    }
    
    /// Applies a tonemapping operation to an HDR image
    /// - Parameter image: The HDR image to tonemap
    /// - Returns: A tonemapped CGImage
    private func applyTonemapping(to image: CGImage) -> CGImage {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply a simple tonemapping (using gamma adjustment as a simple example)
        let gammaFilter = CIFilter(name: "CIGammaAdjust")!
        gammaFilter.setValue(ciImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.5, forKey: "inputPower") // Gamma < 1 expands shadows
        
        guard let gammaOutput = gammaFilter.outputImage else {
            fatalError("Failed to create gamma filter output image")
        }
        
        // Apply a slight color adjustment to enhance the image
        let colorFilter = CIFilter(name: "CIColorControls")!
        colorFilter.setValue(gammaOutput, forKey: kCIInputImageKey)
        colorFilter.setValue(1.1, forKey: "inputSaturation") // Slightly increase saturation
        colorFilter.setValue(0.05, forKey: "inputBrightness") // Slightly increase brightness
        colorFilter.setValue(1.1, forKey: "inputContrast") // Slightly increase contrast
        
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