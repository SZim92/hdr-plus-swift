import Foundation
import XCTest
import CoreGraphics
import CoreImage

#if os(macOS)
import AppKit
#endif

/// Simplified utility for visual testing and image comparison.
/// Provides methods for comparing images, generating diff visualizations, and managing reference images.
/// This is a standalone version adapted from the main project.
public final class VisualTestUtility {
    
    /// Compares a test image to a reference image
    /// - Parameters:
    ///   - testImage: The test image to compare
    ///   - referenceName: Name of the reference image (without extension)
    ///   - tolerance: The comparison tolerance (0.0-1.0)
    ///   - testCase: The test case calling this method
    /// - Returns: True if images match within tolerance
    @discardableResult
    static func compareImage(_ testImage: CGImage,
                             toReferenceNamed referenceName: String,
                             tolerance: Double = 0.01,
                             in testCase: XCTestCase) -> Bool {
        
        // Get reference directory - we'll use a standard location
        let fileManager = FileManager.default
        let referenceDirPath = "StandaloneTests/ReferenceImages"
        let referenceDir = URL(fileURLWithPath: referenceDirPath)
        
        // Create the directory if it doesn't exist
        try? fileManager.createDirectory(at: referenceDir, withIntermediateDirectories: true)
        
        // Path to reference image
        let referencePath = referenceDir.appendingPathComponent("\(referenceName).png")
        
        // If reference image doesn't exist, save the test image as reference
        if !fileManager.fileExists(atPath: referencePath.path) {
            print("Reference image doesn't exist. Creating one.")
            saveImage(testImage, to: referencePath)
            return true
        }
        
        // Load reference image
        guard let referenceImage = loadImageFrom(referencePath) else {
            print("Failed to load reference image")
            return false
        }
        
        // Compare dimensions
        guard testImage.width == referenceImage.width,
              testImage.height == referenceImage.height else {
            print("Image dimensions don't match")
            return false
        }
        
        // Compare pixel data
        let difference = comparePixels(testImage: testImage, referenceImage: referenceImage)
        
        // Check if difference is within tolerance
        let pass = difference <= tolerance
        
        // If failed, generate diff image
        if !pass {
            print("Images differ by \(difference * 100)%, which exceeds tolerance of \(tolerance * 100)%")
            
            // Create diff image and save it
            if let diffImage = generateDiffImage(testImage: testImage, referenceImage: referenceImage) {
                let diffDir = URL(fileURLWithPath: "StandaloneTests/DiffImages")
                try? fileManager.createDirectory(at: diffDir, withIntermediateDirectories: true)
                
                let diffPath = diffDir.appendingPathComponent("\(referenceName)_diff.png")
                saveImage(diffImage, to: diffPath)
                
                print("Diff image saved to \(diffPath.path)")
            }
        } else {
            print("Images match within tolerance")
        }
        
        return pass
    }
    
    // MARK: - Helper Methods
    
    /// Load an image from a file path
    /// - Parameter url: Path to the image file
    /// - Returns: CGImage if successful, nil otherwise
    private static func loadImageFrom(_ url: URL) -> CGImage? {
        #if os(macOS)
        if let nsImage = NSImage(contentsOf: url) {
            var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
            return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        }
        #endif
        return nil
    }
    
    /// Save an image to a file path
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: Path where the image should be saved
    private static func saveImage(_ image: CGImage, to url: URL) {
        #if os(macOS)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
        #endif
    }
    
    /// Compare pixels between two images
    /// - Parameters:
    ///   - testImage: Test image
    ///   - referenceImage: Reference image
    /// - Returns: Difference value between 0.0 and 1.0
    private static func comparePixels(testImage: CGImage, referenceImage: CGImage) -> Double {
        let width = testImage.width
        let height = testImage.height
        let bytesPerPixel = 4
        let totalPixels = width * height
        
        // Get pixel data
        guard let testData = getPixelData(testImage),
              let referenceData = getPixelData(referenceImage) else {
            return 1.0 // Maximum difference if we can't get pixel data
        }
        
        defer {
            free(testData)
            free(referenceData)
        }
        
        // Count differing pixels
        var differentPixels = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let testR = testData[pixelIndex]
                let testG = testData[pixelIndex + 1]
                let testB = testData[pixelIndex + 2]
                let testA = testData[pixelIndex + 3]
                
                let refR = referenceData[pixelIndex]
                let refG = referenceData[pixelIndex + 1]
                let refB = referenceData[pixelIndex + 2]
                let refA = referenceData[pixelIndex + 3]
                
                if testR != refR || testG != refG || testB != refB || testA != refA {
                    differentPixels += 1
                }
            }
        }
        
        return Double(differentPixels) / Double(totalPixels)
    }
    
    /// Generate a diff image highlighting differences
    /// - Parameters:
    ///   - testImage: Test image
    ///   - referenceImage: Reference image
    /// - Returns: A CGImage showing differences
    private static func generateDiffImage(testImage: CGImage, referenceImage: CGImage) -> CGImage? {
        let width = testImage.width
        let height = testImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Get pixel data
        guard let testData = getPixelData(testImage),
              let referenceData = getPixelData(referenceImage) else {
            return nil
        }
        
        defer {
            free(testData)
            free(referenceData)
        }
        
        // Create diff data
        let diffData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)
        defer { diffData.deallocate() }
        
        // Initialize with white background
        for i in 0..<(width * height * bytesPerPixel) {
            diffData[i] = 255
        }
        
        // Mark differences in red
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let testR = testData[pixelIndex]
                let testG = testData[pixelIndex + 1]
                let testB = testData[pixelIndex + 2]
                let testA = testData[pixelIndex + 3]
                
                let refR = referenceData[pixelIndex]
                let refG = referenceData[pixelIndex + 1]
                let refB = referenceData[pixelIndex + 2]
                let refA = referenceData[pixelIndex + 3]
                
                if testR != refR || testG != refG || testB != refB || testA != refA {
                    diffData[pixelIndex] = 255     // R (red)
                    diffData[pixelIndex + 1] = 0   // G
                    diffData[pixelIndex + 2] = 0   // B
                    diffData[pixelIndex + 3] = 255 // A
                }
            }
        }
        
        // Create context and image
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: diffData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    /// Get raw pixel data from an image
    /// - Parameter image: The image to get pixel data from
    /// - Returns: Pointer to pixel data
    private static func getPixelData(_ image: CGImage) -> UnsafeMutablePointer<UInt8>? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            free(data)
            return nil
        }
        
        // Draw image into context
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return data
    }
} 