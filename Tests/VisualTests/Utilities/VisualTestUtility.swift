import XCTest
import AppKit
import Foundation

/// A utility class for visual regression testing
class VisualTestUtility {
    
    /// The directory containing reference images
    static let referenceDirectory = "ReferenceImages"
    
    /// The directory for failed test artifacts
    static let failureDirectory = "FailedTests"
    
    /// The tolerance for image comparison (0.0 - 1.0)
    static var defaultTolerance: CGFloat = 0.01
    
    /**
     Compare an image to a reference image
     
     - Parameters:
        - image: The image to test
        - referenceNamed: The name of the reference image
        - tolerance: The comparison tolerance (0.0 - 1.0)
        - testCase: The XCTestCase instance
     - Returns: True if images match within tolerance, false otherwise
     */
    static func compareImage(_ image: NSImage, 
                           toReferenceNamed referenceNamed: String, 
                           tolerance: CGFloat = defaultTolerance,
                           in testCase: XCTestCase) -> Bool {
        // Get test name for file naming
        let testName = testCase.name.components(separatedBy: " ")[0]
        let fileName = "\(testName)_\(referenceNamed)"
        
        // Create directories if needed
        ensureDirectoryExists(referenceDirectory)
        ensureDirectoryExists(failureDirectory)
        
        // Convert image to bitmap for comparison
        guard let imageData = convertToBitmapData(image) else {
            XCTFail("Failed to convert test image to bitmap data")
            return false
        }
        
        // Check for reference image
        let referenceURL = URL(fileURLWithPath: "\(referenceDirectory)/\(fileName).png")
        
        // If reference image doesn't exist, save current image as reference
        guard FileManager.default.fileExists(atPath: referenceURL.path) else {
            saveReferenceImage(image, fileName: fileName)
            XCTFail("Reference image not found. Current image saved as reference. Test will fail this time.")
            return false
        }
        
        // Load reference image
        guard let referenceImage = NSImage(contentsOf: referenceURL),
              let referenceData = convertToBitmapData(referenceImage) else {
            XCTFail("Failed to load reference image")
            return false
        }
        
        // Compare images
        let (match, diffPercentage) = compareImageData(imageData, referenceData)
        
        // Handle failed comparison
        if !match {
            // Save the test image and diff image
            saveFailedTestArtifacts(testImage: image, referenceImage: referenceImage, fileName: fileName)
            
            // Report failure with diff percentage
            XCTFail("Image comparison failed. Difference: \(Int(diffPercentage * 100))%. " +
                    "Test image saved to \(failureDirectory)/\(fileName)_failed.png")
            return false
        }
        
        return true
    }
    
    /**
     Save an image as a reference image
     
     - Parameters:
        - image: The image to save
        - fileName: The file name without extension
     */
    static func saveReferenceImage(_ image: NSImage, fileName: String) {
        saveImage(image, to: referenceDirectory, fileName: fileName)
    }
    
    /**
     Save artifacts from a failed test
     
     - Parameters:
        - testImage: The test image
        - referenceImage: The reference image
        - fileName: The file name without extension
     */
    static func saveFailedTestArtifacts(testImage: NSImage, referenceImage: NSImage, fileName: String) {
        // Save the test image
        saveImage(testImage, to: failureDirectory, fileName: "\(fileName)_failed")
        
        // Save the reference image for comparison
        saveImage(referenceImage, to: failureDirectory, fileName: "\(fileName)_reference")
        
        // Generate and save diff image
        if let diffImage = generateDiffImage(testImage, referenceImage) {
            saveImage(diffImage, to: failureDirectory, fileName: "\(fileName)_diff")
        }
    }
    
    /**
     Convert an NSImage to bitmap data for comparison
     
     - Parameter image: The image to convert
     - Returns: Bitmap data for the image, or nil if conversion failed
     */
    private static func convertToBitmapData(_ image: NSImage) -> [UInt8]? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height
        
        var imageData = [UInt8](repeating: 0, count: totalBytes)
        
        guard let context = CGContext(data: &imageData,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return imageData
    }
    
    /**
     Compare two sets of image data
     
     - Parameters:
        - data1: First image data
        - data2: Second image data
        - tolerance: Comparison tolerance (0.0 - 1.0)
     - Returns: Tuple containing (match, diffPercentage)
     */
    private static func compareImageData(_ data1: [UInt8], _ data2: [UInt8], tolerance: CGFloat = defaultTolerance) -> (Bool, CGFloat) {
        // Check sizes
        guard data1.count == data2.count, data1.count > 0 else {
            return (false, 1.0)
        }
        
        // Compare bytes
        var differentPixels = 0
        let totalPixels = data1.count / 4 // RGBA
        
        for i in stride(from: 0, to: data1.count, by: 4) {
            // Compare only RGB (ignore alpha)
            let pixelDifferent = (abs(Int(data1[i]) - Int(data2[i])) > 10) ||
                                (abs(Int(data1[i+1]) - Int(data2[i+1])) > 10) ||
                                (abs(Int(data1[i+2]) - Int(data2[i+2])) > 10)
            
            if pixelDifferent {
                differentPixels += 1
            }
        }
        
        let diffPercentage = CGFloat(differentPixels) / CGFloat(totalPixels)
        return (diffPercentage <= tolerance, diffPercentage)
    }
    
    /**
     Generate a visual diff image highlighting differences
     
     - Parameters:
        - image1: First image
        - image2: Second image
     - Returns: A diff image highlighting differences, or nil if generation failed
     */
    private static func generateDiffImage(_ image1: NSImage, _ image2: NSImage) -> NSImage? {
        guard let data1 = convertToBitmapData(image1),
              let data2 = convertToBitmapData(image2),
              data1.count == data2.count,
              let cgImage1 = image1.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let width = cgImage1.width
        let height = cgImage1.height
        let bytesPerRow = width * 4
        
        var diffData = [UInt8](repeating: 0, count: data1.count)
        
        // Create diff visualization (red for differences)
        for i in stride(from: 0, to: data1.count, by: 4) {
            if (abs(Int(data1[i]) - Int(data2[i])) > 10) ||
               (abs(Int(data1[i+1]) - Int(data2[i+1])) > 10) ||
               (abs(Int(data1[i+2]) - Int(data2[i+2])) > 10) {
                // Mark difference in red
                diffData[i] = 255     // R
                diffData[i+1] = 0     // G
                diffData[i+2] = 0     // B
                diffData[i+3] = 255   // A
            } else {
                // Keep original pixel with reduced opacity
                diffData[i] = data1[i]
                diffData[i+1] = data1[i+1]
                diffData[i+2] = data1[i+2]
                diffData[i+3] = 100   // Semi-transparent
            }
        }
        
        // Create CGImage from diff data
        guard let provider = CGDataProvider(data: Data(bytes: diffData, count: diffData.count) as CFData),
              let cgImage = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            return nil
        }
        
        // Create NSImage from CGImage
        let diffImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        return diffImage
    }
    
    /**
     Save an image to a file
     
     - Parameters:
        - image: The image to save
        - directory: The directory to save to
        - fileName: The file name without extension
     */
    private static func saveImage(_ image: NSImage, to directory: String, fileName: String) {
        ensureDirectoryExists(directory)
        
        let url = URL(fileURLWithPath: "\(directory)/\(fileName).png")
        
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: url)
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
    
    /**
     Ensure a directory exists, creating it if necessary
     
     - Parameter path: The directory path
     */
    private static func ensureDirectoryExists(_ path: String) {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
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