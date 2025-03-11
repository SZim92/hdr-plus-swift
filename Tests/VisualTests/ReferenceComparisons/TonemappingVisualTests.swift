import XCTest
import AppKit
@testable import HDRPlusCore // Assume this is the module name

class TonemappingVisualTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Skip visual tests if the environment variable is set
        if ProcessInfo.processInfo.environment["SKIP_VISUAL_TESTS"] == "1" {
            throw XCTSkip("Visual tests are disabled via environment variable")
        }
    }
    
    func testBasicTonemapping() throws {
        // This test verifies the basic tonemapping functionality
        // by comparing the result to a reference image
        
        // Load test image (in a real test, we'd load from TestResources)
        guard let inputImage = createTestHDRImage(width: 800, height: 600) else {
            XCTFail("Failed to create test image")
            return
        }
        
        // Process the image using our tonemapping algorithm
        // In a real test, we'd call the actual HDR+ tonemapping function
        let processedImage = simulateTonemapping(inputImage)
        
        // Compare with reference image
        let matchesReference = VisualTestUtility.compareImage(
            processedImage,
            toReferenceNamed: "basic_tonemapping",
            tolerance: 0.015, // 1.5% difference tolerance
            in: self
        )
        
        XCTAssertTrue(matchesReference, "Tonemapped image should match reference within tolerance")
    }
    
    func testHighContrastTonemapping() throws {
        // This test verifies tonemapping with high contrast scenes
        
        // Load high contrast test image
        guard let inputImage = createHighContrastTestImage(width: 800, height: 600) else {
            XCTFail("Failed to create high contrast test image")
            return
        }
        
        // Process the image using our tonemapping algorithm
        let processedImage = simulateTonemapping(inputImage)
        
        // Compare with reference image
        let matchesReference = VisualTestUtility.compareImage(
            processedImage,
            toReferenceNamed: "high_contrast_tonemapping",
            tolerance: 0.02, // 2% difference tolerance for high contrast scenes
            in: self
        )
        
        XCTAssertTrue(matchesReference, "High contrast tonemapped image should match reference within tolerance")
    }
    
    // MARK: - Helper methods
    
    /// Creates a simulated HDR test image with a gradient and bright spots
    private func createTestHDRImage(width: Int, height: Int) -> NSImage? {
        let image = NSImage(size: NSSize(width: width, height: height))
        
        image.lockFocus()
        
        // Create a gradient background
        let gradient = NSGradient(
            colors: [NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.3, alpha: 1.0),
                     NSColor(calibratedRed: 0.5, green: 0.6, blue: 0.7, alpha: 1.0)]
        )
        gradient?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 45)
        
        // Add some bright spots to simulate HDR highlights
        let highlightColor = NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.7, alpha: 1.0)
        highlightColor.setFill()
        
        // Draw a bright sun
        let sunPath = NSBezierPath(ovalIn: NSRect(x: width * 0.7, y: height * 0.7, width: 100, height: 100))
        sunPath.fill()
        
        // Draw some bright reflections
        let reflection1 = NSBezierPath(ovalIn: NSRect(x: width * 0.2, y: height * 0.3, width: 50, height: 20))
        reflection1.fill()
        
        let reflection2 = NSBezierPath(ovalIn: NSRect(x: width * 0.5, y: height * 0.2, width: 70, height: 30))
        reflection2.fill()
        
        image.unlockFocus()
        
        return image
    }
    
    /// Creates a high contrast HDR image with very bright and very dark areas
    private func createHighContrastTestImage(width: Int, height: Int) -> NSImage? {
        let image = NSImage(size: NSSize(width: width, height: height))
        
        image.lockFocus()
        
        // Create a dark background
        NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.1, alpha: 1.0).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        
        // Add very bright elements
        let brightColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0)
        brightColor.setFill()
        
        // Draw a very bright light source
        let lightSource = NSBezierPath(ovalIn: NSRect(x: width * 0.3, y: height * 0.6, width: 150, height: 150))
        lightSource.fill()
        
        // Draw some shadow areas
        NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.03, alpha: 1.0).setFill()
        let shadow1 = NSBezierPath(rect: NSRect(x: width * 0.1, y: height * 0.1, width: width * 0.3, height: height * 0.2))
        shadow1.fill()
        
        image.unlockFocus()
        
        return image
    }
    
    /// Simulates an HDR tonemapping operation
    /// In a real test, this would call the actual HDR+ tonemapping function
    private func simulateTonemapping(_ inputImage: NSImage) -> NSImage {
        // Create a copy of the image to modify
        guard let imageData = inputImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let cgImage = bitmap.cgImage else {
            return inputImage
        }
        
        let outputImage = NSImage(cgImage: cgImage, size: inputImage.size)
        
        // In a real implementation, we would apply actual tonemapping here
        // For demo purposes, we're just simulating the effect
        
        return outputImage
    }
} 