import XCTest
import AppKit
import Foundation

/// Utility class for visual regression testing
public class VisualTestUtility {
    
    // MARK: - Constants
    
    /// Default directory for reference images
    private static let referenceImageDirectory = "ReferenceImages"
    
    /// Directory for failed test artifacts
    private static let failedTestArtifactsDirectory = "FailedTestArtifacts"
    
    /// Tolerance configuration levels
    public enum ToleranceLevel {
        case strict      // 0.5% difference
        case normal      // 1% difference
        case lenient     // 2% difference
        case custom(Float) // Custom percentage
        
        var percentage: Float {
            switch self {
            case .strict: return 0.005
            case .normal: return 0.01
            case .lenient: return 0.02
            case .custom(let value): return value
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Compares an image to a reference image with the specified tolerance
    ///
    /// - Parameters:
    ///   - image: The image to test
    ///   - referenceName: Name of the reference image
    ///   - tolerance: Allowed percentage difference (0-1.0)
    ///   - testCase: The test case this is being called from
    /// - Returns: Whether the image matches the reference within tolerance
    @discardableResult
    public static func compareImage(
        _ image: NSImage,
        toReferenceNamed referenceName: String,
        tolerance: Float = 0.01,
        in testCase: XCTestCase
    ) -> Bool {
        let testClass = type(of: testCase)
        let testName = testCase.name
        
        // Construct base filename from test
        let fileName = "\(testClass)-\(referenceName)"
        
        // Try to load reference image
        guard let referenceURL = referenceFileURL(fileName: fileName, testClass: testClass) else {
            // If no reference image exists, save this one as reference and return true
            print("⚠️ No reference image found for '\(fileName)'. Creating new reference.")
            saveReferenceImage(image, fileName: fileName, testClass: testClass)
            return true
        }
        
        guard let referenceImage = NSImage(contentsOf: referenceURL) else {
            XCTFail("Failed to load reference image at: \(referenceURL.path)")
            return false
        }
        
        // Convert images to bitmap data for comparison
        guard let imageData = convertToBitmapData(image),
              let referenceData = convertToBitmapData(referenceImage) else {
            XCTFail("Failed to convert images to bitmap data")
            return false
        }
        
        // Check if the dimensions match
        guard imageData.count == referenceData.count else {
            XCTFail("Image size (\(imageData.count) bytes) doesn't match reference (\(referenceData.count) bytes)")
            saveFailedTestArtifacts(
                testImage: image,
                referenceImage: referenceImage,
                fileName: fileName,
                testClass: testClass
            )
            return false
        }
        
        // Compare the images
        let (matches, diffPercentage) = compareImageData(imageData, referenceData, tolerance: tolerance)
        
        if !matches {
            XCTFail("Image differs from reference by \(String(format: "%.2f", diffPercentage * 100))% (tolerance: \(String(format: "%.2f", tolerance * 100))%)")
            saveFailedTestArtifacts(
                testImage: image,
                referenceImage: referenceImage,
                fileName: fileName,
                testClass: testClass
            )
            return false
        }
        
        return true
    }
    
    /// Saves an image as a reference image for future comparisons
    ///
    /// - Parameters:
    ///   - image: The image to save as reference
    ///   - fileName: Name to save the reference as
    ///   - testClass: The test class this is for
    public static func saveReferenceImage(_ image: NSImage, fileName: String, testClass: AnyClass) {
        let directoryURL = referenceDirectoryURL(testClass: testClass)
        ensureDirectoryExists(directoryURL)
        
        saveImage(image, to: directoryURL, fileName: fileName)
    }
    
    /// Saves artifacts from a failed test for debugging
    ///
    /// - Parameters:
    ///   - testImage: The test image that failed
    ///   - referenceImage: The reference image
    ///   - fileName: Base name for the files
    ///   - testClass: The test class this is for
    public static func saveFailedTestArtifacts(
        testImage: NSImage,
        referenceImage: NSImage,
        fileName: String,
        testClass: AnyClass
    ) {
        let directoryURL = failedTestArtifactsDirectoryURL(testClass: testClass)
        ensureDirectoryExists(directoryURL)
        
        // Save test image
        saveImage(testImage, to: directoryURL, fileName: "\(fileName)_failed")
        
        // Save reference image (for convenience)
        saveImage(referenceImage, to: directoryURL, fileName: "\(fileName)_reference")
        
        // Generate and save diff image
        if let diffImage = generateDiffImage(testImage, referenceImage) {
            saveImage(diffImage, to: directoryURL, fileName: "\(fileName)_diff")
        }
        
        print("📸 Test images saved to: \(directoryURL.path)")
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a bitmap representation of an image for comparison
    private static func convertToBitmapData(_ image: NSImage) -> [UInt8]? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // Ensure we have a consistent pixel format
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        var data = [UInt8](repeating: 0, count: width * height * 4) // RGBA format
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                
                // Get color at pixel
                if let color = bitmap.colorAt(x: x, y: y) {
                    // Convert to sRGB color space for consistent comparison
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    color.getRed(&r, green: &g, blue: &b, alpha: &a)
                    
                    // Store as bytes
                    data[pixelIndex] = UInt8(r * 255)
                    data[pixelIndex + 1] = UInt8(g * 255)
                    data[pixelIndex + 2] = UInt8(b * 255)
                    data[pixelIndex + 3] = UInt8(a * 255)
                }
            }
        }
        
        return data
    }
    
    /// Compares two sets of image data with a tolerance
    private static func compareImageData(
        _ data1: [UInt8],
        _ data2: [UInt8],
        tolerance: Float
    ) -> (Bool, Float) {
        var totalDifference: Float = 0
        let pixelCount = data1.count / 4
        
        for i in stride(from: 0, to: data1.count, by: 4) {
            // Compare RGBA values
            let r1 = Float(data1[i]) / 255.0
            let g1 = Float(data1[i+1]) / 255.0
            let b1 = Float(data1[i+2]) / 255.0
            let a1 = Float(data1[i+3]) / 255.0
            
            let r2 = Float(data2[i]) / 255.0
            let g2 = Float(data2[i+1]) / 255.0
            let b2 = Float(data2[i+2]) / 255.0
            let a2 = Float(data2[i+3]) / 255.0
            
            // Calculate the difference for this pixel (weighted by alpha)
            let alpha = (a1 + a2) / 2 // Average alpha
            let diff = (abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)) * alpha / 3
            
            totalDifference += diff
        }
        
        // Calculate average difference across all pixels
        let diffPercentage = totalDifference / Float(pixelCount)
        
        return (diffPercentage <= tolerance, diffPercentage)
    }
    
    /// Generates a visual diff image highlighting differences
    private static func generateDiffImage(_ image1: NSImage, _ image2: NSImage) -> NSImage? {
        // Get the dimensions of both images
        let size1 = image1.size
        let size2 = image2.size
        
        // Use the larger dimensions for the diff image
        let width = max(Int(size1.width), Int(size2.width))
        let height = max(Int(size1.height), Int(size2.height))
        
        // Create bitmap data for both images
        guard let data1 = convertToBitmapData(image1),
              let data2 = convertToBitmapData(image2) else {
            return nil
        }
        
        // Create a new image to show the differences
        let diffImage = NSImage(size: NSSize(width: width, height: height))
        
        // Create a bitmap representation for the diff image
        guard let diffRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }
        
        // Process each pixel to highlight differences
        let pixelCount = min(data1.count, data2.count) / 4
        
        for i in 0..<pixelCount {
            let pixelIndex = i * 4
            
            // Get pixel values from both images
            let r1 = CGFloat(data1[pixelIndex]) / 255.0
            let g1 = CGFloat(data1[pixelIndex + 1]) / 255.0
            let b1 = CGFloat(data1[pixelIndex + 2]) / 255.0
            let a1 = CGFloat(data1[pixelIndex + 3]) / 255.0
            
            let r2 = CGFloat(data2[pixelIndex]) / 255.0
            let g2 = CGFloat(data2[pixelIndex + 1]) / 255.0
            let b2 = CGFloat(data2[pixelIndex + 2]) / 255.0
            let a2 = CGFloat(data2[pixelIndex + 3]) / 255.0
            
            // Calculate pixel coordinates
            let x = i % width
            let y = i / width
            
            // Calculate difference magnitude
            let diff = (abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)) / 3.0
            
            // Color based on difference (red for differences, blend of original colors for similar)
            let color: NSColor
            if diff > 0.05 {  // More than 5% difference
                // Highlight in red, intensity based on difference
                let intensity = min(1.0, diff * 5.0)  // Scale up for visibility
                color = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: intensity)
            } else {
                // Average the two pixels for similar areas with slight transparency
                let avgR = (r1 + r2) / 2.0
                let avgG = (g1 + g2) / 2.0
                let avgB = (b1 + b2) / 2.0
                let avgA = (a1 + a2) / 2.0 * 0.7  // Reduce opacity for easier viewing
                
                color = NSColor(calibratedRed: avgR, green: avgG, blue: avgB, alpha: avgA)
            }
            
            // Set the pixel in the diff image
            diffRep.setColor(color, atX: x, y: y)
        }
        
        // Add the representation to the diff image
        diffImage.addRepresentation(diffRep)
        
        return diffImage
    }
    
    /// Saves an image to disk
    private static func saveImage(_ image: NSImage, to directory: URL, fileName: String) {
        let fileURL = directory.appendingPathComponent("\(fileName).png")
        
        // Convert to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("⚠️ Failed to convert image to PNG for saving")
            return
        }
        
        do {
            try pngData.write(to: fileURL)
            print("✅ Saved image to: \(fileURL.path)")
        } catch {
            print("⚠️ Failed to save image: \(error.localizedDescription)")
        }
    }
    
    /// Ensures a directory exists, creating it if necessary
    private static func ensureDirectoryExists(_ url: URL) {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                print("📁 Created directory: \(url.path)")
            } catch {
                print("⚠️ Failed to create directory: \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets the URL for the reference images directory
    private static func referenceDirectoryURL(testClass: AnyClass) -> URL {
        let bundle = Bundle(for: testClass)
        let testModuleName = String(describing: testClass).components(separatedBy: ".").first ?? "TestModule"
        
        // Try to find TestResources directory relative to the test bundle
        var resourcesURL = bundle.bundleURL.deletingLastPathComponent()
                                 .appendingPathComponent("TestResources")
                                 .appendingPathComponent(referenceImageDirectory)
                                 .appendingPathComponent(testModuleName)
        
        // Alternative: check for Resources directory inside the bundle
        if !FileManager.default.fileExists(atPath: resourcesURL.path),
           let bundleResourcesURL = bundle.resourceURL {
            resourcesURL = bundleResourcesURL.appendingPathComponent(referenceImageDirectory)
                                           .appendingPathComponent(testModuleName)
        }
        
        return resourcesURL
    }
    
    /// Gets the URL for a reference image file
    private static func referenceFileURL(fileName: String, testClass: AnyClass) -> URL? {
        let directory = referenceDirectoryURL(testClass: testClass)
        let fileURL = directory.appendingPathComponent("\(fileName).png")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        return nil
    }
    
    /// Gets the URL for the failed test artifacts directory
    private static func failedTestArtifactsDirectoryURL(testClass: AnyClass) -> URL {
        let bundle = Bundle(for: testClass)
        let testModuleName = String(describing: testClass).components(separatedBy: ".").first ?? "TestModule"
        
        // Use build directory for test artifacts
        var buildDir = bundle.bundleURL.deletingLastPathComponent()
        
        // If we're in Xcode test environment, use DerivedData
        if let derivedDataPath = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            buildDir = URL(fileURLWithPath: derivedDataPath)
        }
        
        return buildDir.appendingPathComponent(failedTestArtifactsDirectory)
                       .appendingPathComponent(testModuleName)
    }
}

extension NSImage {
    /**
     Create a small preview image for visual testing
     
     - Parameter size: The size of the preview image
     - Returns: A downsampled preview image
     */
    func createPreview(size: NSSize) -> NSImage {
        let preview = NSImage(size: size)
        preview.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), 
                  operation: .copy, fraction: 1.0)
                  
        preview.unlockFocus()
        return preview
    }
} 