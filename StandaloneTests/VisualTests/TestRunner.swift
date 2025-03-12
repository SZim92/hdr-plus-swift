import XCTest
import Foundation

#if os(macOS)
import AppKit
#endif

/// Simple standalone test runner for visual tests
/// This avoids dependencies on the main application
class StandaloneTestRunner: XCTestCase {
    
    /// Set up test environment
    override func setUp() {
        super.setUp()
        print("Setting up standalone test environment")
        
        // Create necessary directories
        let fileManager = FileManager.default
        let directories = [
            "StandaloneTests/ReferenceImages",
            "StandaloneTests/TestOutput",
            "StandaloneTests/DiffImages"
        ]
        
        for directory in directories {
            try? fileManager.createDirectory(at: URL(fileURLWithPath: directory), 
                                          withIntermediateDirectories: true)
        }
    }
    
    /// Basic test to verify the test runner works
    func testRunnerWorks() {
        print("Running standalone test")
        XCTAssertTrue(true, "Standalone test runner is working")
    }
    
    /// Example visual test that creates and verifies a test image
    func testBasicVisualComparison() {
        // Create a simple test image
        let width = 200
        let height = 200
        
        print("Creating test image \(width)x\(height)")
        let redColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let testImage = createTestImage(width: width, height: height, color: redColor)
        
        // Save the image to a test directory
        saveTestImage(testImage, name: "basic_red_square")
        
        // Compare with reference image using our utility
        let matches = VisualTestUtility.compareImage(
            testImage, 
            toReferenceNamed: "basic_red_square", 
            tolerance: 0.01, 
            in: self
        )
        
        XCTAssertTrue(matches, "Image should match reference image")
        
        print("Successfully created and verified test image")
    }
    
    /// Test with a more complex gradient image
    func testGradientImage() {
        print("Creating gradient test image")
        let testImage = createGradientImage(width: 300, height: 200)
        
        // Save the image for inspection
        saveTestImage(testImage, name: "gradient")
        
        // Compare with reference image
        let matches = VisualTestUtility.compareImage(
            testImage,
            toReferenceNamed: "gradient",
            tolerance: 0.01,
            in: self
        )
        
        XCTAssertTrue(matches, "Gradient image should match reference image")
    }
    
    /// Test with a blurred image
    func testBlurredImage() {
        // Create a base image
        print("Creating and testing blurred image")
        let blueColor = CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let baseImage = createTestImage(width: 200, height: 200, color: blueColor)
        
        // Apply blur
        let blurredImage = applyBlur(to: baseImage, radius: 10.0)
        
        // Save for inspection
        saveTestImage(blurredImage, name: "blurred_blue")
        
        // Compare with reference
        let matches = VisualTestUtility.compareImage(
            blurredImage,
            toReferenceNamed: "blurred_blue",
            tolerance: 0.01,
            in: self
        )
        
        XCTAssertTrue(matches, "Blurred image should match reference image")
    }
    
    // MARK: - Helper Methods
    
    /// Helper function to save a test image
    private func saveTestImage(_ image: CGImage, name: String) {
        let outputDir = URL(fileURLWithPath: "StandaloneTests/TestOutput")
        let outputURL = outputDir.appendingPathComponent("\(name).png")
        
        #if os(macOS)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: outputURL)
            print("Saved test image to \(outputURL.path)")
        }
        #endif
    }
    
    /// Creates a solid color test image
    private func createTestImage(width: Int, height: Int, color: CGColor) -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        // Create bitmap context
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        // Fill with color
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()!
    }
    
    /// Creates a gradient image
    private func createGradientImage(width: Int, height: Int) -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        // Create bitmap context
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        // Create gradient
        let colors = [
            CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
            CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),
            CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        ]
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: [0.0, 0.5, 1.0]
        )!
        
        // Draw gradient
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: width, y: height)
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
        
        return context.makeImage()!
    }
    
    /// Applies a blur effect to an image
    private func applyBlur(to image: CGImage, radius: Double) -> CGImage {
        #if os(macOS)
        let ciImage = CIImage(cgImage: image)
        
        // Create blur filter
        let filter = CIFilter(name: "CIGaussianBlur")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        
        // Get output
        guard let outputImage = filter.outputImage else {
            return image
        }
        
        // Create CG image
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return cgImage
        #else
        return image
        #endif
    }
}
