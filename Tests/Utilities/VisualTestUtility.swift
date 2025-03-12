import XCTest
import Foundation
import CoreGraphics
import CoreImage

/// VisualTestUtility provides functionality for visual regression testing, 
/// including comparing images, generating visual diffs, and managing reference images.
class VisualTestUtility {
    
    // MARK: - Image Comparison
    
    /// Compares a test image with a reference image for visual regression testing
    /// - Parameters:
    ///   - testImage: The test image to compare
    ///   - referenceName: The name of the reference image
    ///   - tolerance: The tolerance for pixel differences (0.0-1.0)
    ///   - testCase: The test case that's performing the comparison
    /// - Returns: True if the images match within the specified tolerance
    static func compareImage(_ testImage: CGImage, 
                             toReferenceNamed referenceName: String,
                             tolerance: Double = TestConfig.shared.visualTestTolerance,
                             in testCase: XCTestCase) -> Bool {
        let config = TestConfig.shared
        config.createDirectories()
        
        let referenceURL = config.referenceImageURL(named: referenceName, for: testCase)
        
        // Check if reference image exists
        if !FileManager.default.fileExists(atPath: referenceURL.path) {
            if config.autoUpdateReferenceImages {
                try? saveReferenceImage(testImage, named: referenceName, in: testCase)
                return true
            } else {
                XCTFail("Reference image \(referenceName) does not exist at \(referenceURL.path)")
                return false
            }
        }
        
        // Load reference image
        guard let referenceImage = loadImage(from: referenceURL) else {
            XCTFail("Failed to load reference image from \(referenceURL.path)")
            return false
        }
        
        // Check dimensions
        guard testImage.width == referenceImage.width && testImage.height == referenceImage.height else {
            XCTFail("Image dimensions do not match: Test image: \(testImage.width)x\(testImage.height), Reference image: \(referenceImage.width)x\(referenceImage.height)")
            saveFailedTestImage(testImage, named: "\(referenceName)_failed", in: testCase)
            return false
        }
        
        // Compare images
        let (diffPercentage, diffImage) = compareImages(testImage, referenceImage)
        
        // Check if difference is within tolerance
        let matches = diffPercentage <= tolerance
        
        if !matches {
            // Save failed test artifacts
            saveFailedTestImage(testImage, named: "\(referenceName)_failed", in: testCase)
            
            if let diffImage = diffImage, config.saveDiffImages {
                saveFailedTestImage(diffImage, named: "\(referenceName)_diff", in: testCase)
            }
            
            XCTFail("Images differ by \(String(format: "%.2f", diffPercentage * 100))%, which exceeds the tolerance of \(String(format: "%.2f", tolerance * 100))%")
        }
        
        return matches
    }
    
    /// Compares two images and returns the percentage difference and a diff image
    /// - Parameters:
    ///   - image1: The first image to compare
    ///   - image2: The second image to compare
    /// - Returns: A tuple containing the percentage difference (0.0-1.0) and an optional diff image
    private static func compareImages(_ image1: CGImage, _ image2: CGImage) -> (Double, CGImage?) {
        // Create CIImages from CGImages
        let ciImage1 = CIImage(cgImage: image1)
        let ciImage2 = CIImage(cgImage: image2)
        
        // Create a difference filter
        let differenceFilter = CIFilter(name: "CIDifferenceBlendMode")!
        differenceFilter.setValue(ciImage1, forKey: kCIInputImageKey)
        differenceFilter.setValue(ciImage2, forKey: kCIInputBackgroundImageKey)
        
        // Apply the filter
        guard let differenceOutput = differenceFilter.outputImage else {
            return (1.0, nil) // Assume maximum difference if filter fails
        }
        
        // Create a context to render the diff image
        let context = CIContext()
        guard let diffCGImage = context.createCGImage(differenceOutput, from: differenceOutput.extent) else {
            return (1.0, nil)
        }
        
        // Calculate the average pixel difference
        let pixelData = calculateAveragePixelValue(diffCGImage)
        
        // Create a highlighted diff image for visualization
        let highlightedDiff = createHighlightedDiffImage(diffCGImage)
        
        return (pixelData, highlightedDiff)
    }
    
    /// Calculates the average pixel value of an image
    /// - Parameter image: The image to analyze
    /// - Returns: The average pixel value (0.0-1.0)
    private static func calculateAveragePixelValue(_ image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height
        
        guard let pixelData = calloc(totalBytes, MemoryLayout<UInt8>.size) else {
            return 1.0 // Assume maximum difference if memory allocation fails
        }
        defer { free(pixelData) }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                               width: width,
                               height: height,
                               bitsPerComponent: 8,
                               bytesPerRow: bytesPerRow,
                               space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate the sum of all pixel values
        var sum: UInt64 = 0
        var count: UInt64 = 0
        
        let buffer = pixelData.bindMemory(to: UInt8.self, capacity: totalBytes)
        for i in stride(from: 0, to: totalBytes, by: 4) {
            let r = buffer[i]
            let g = buffer[i + 1]
            let b = buffer[i + 2]
            
            // Calculate luminance using standard weights
            let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
            sum += UInt64(luminance)
            count += 1
        }
        
        // Calculate the average pixel value (normalized to 0.0-1.0)
        let average = Double(sum) / (Double(count) * 255.0)
        
        return average
    }
    
    /// Creates a highlighted diff image for better visualization of differences
    /// - Parameter diffImage: The difference image
    /// - Returns: A highlighted diff image
    private static func createHighlightedDiffImage(_ diffImage: CGImage) -> CGImage? {
        let width = diffImage.width
        let height = diffImage.height
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height
        
        guard let pixelData = calloc(totalBytes, MemoryLayout<UInt8>.size) else {
            return nil
        }
        defer { free(pixelData) }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                               width: width,
                               height: height,
                               bitsPerComponent: 8,
                               bytesPerRow: bytesPerRow,
                               space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context?.draw(diffImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create a new buffer for the highlighted image
        guard let highlightedData = calloc(totalBytes, MemoryLayout<UInt8>.size) else {
            return nil
        }
        defer { free(highlightedData) }
        
        let buffer = pixelData.bindMemory(to: UInt8.self, capacity: totalBytes)
        let highlightedBuffer = highlightedData.bindMemory(to: UInt8.self, capacity: totalBytes)
        
        // Highlight differences in red
        for i in stride(from: 0, to: totalBytes, by: 4) {
            let r = buffer[i]
            let g = buffer[i + 1]
            let b = buffer[i + 2]
            let a = buffer[i + 3]
            
            // Calculate luminance
            let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
            
            // If there's a significant difference, highlight it
            if luminance > 10.0 {
                // Bright red for differences
                highlightedBuffer[i] = 255     // R
                highlightedBuffer[i + 1] = 0   // G
                highlightedBuffer[i + 2] = 0   // B
                highlightedBuffer[i + 3] = 255 // A
            } else {
                // Original pixel values for matching areas
                highlightedBuffer[i] = r
                highlightedBuffer[i + 1] = g
                highlightedBuffer[i + 2] = b
                highlightedBuffer[i + 3] = a
            }
        }
        
        // Create a context for the highlighted image
        let highlightedContext = CGContext(data: highlightedData,
                                         width: width,
                                         height: height,
                                         bitsPerComponent: 8,
                                         bytesPerRow: bytesPerRow,
                                         space: colorSpace,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        return highlightedContext?.makeImage()
    }
    
    // MARK: - Image Management
    
    /// Saves an image as a reference image
    /// - Parameters:
    ///   - image: The image to save
    ///   - name: The name for the reference image
    ///   - testCase: The test case that's saving the reference image
    static func saveReferenceImage(_ image: CGImage, named name: String, in testCase: XCTestCase) throws {
        let config = TestConfig.shared
        let referenceURL = config.referenceImageURL(named: name, for: testCase)
        
        // Create the directory if it doesn't exist
        let directoryURL = referenceURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        // Save the image
        try saveImage(image, to: referenceURL)
        
        print("Saved reference image: \(referenceURL.path)")
    }
    
    /// Saves an image for a failed test
    /// - Parameters:
    ///   - image: The image to save
    ///   - name: The name for the failed test image
    ///   - testCase: The test case that's saving the failed test image
    private static func saveFailedTestImage(_ image: CGImage, named name: String, in testCase: XCTestCase) {
        let config = TestConfig.shared
        let failedURL = config.failedTestArtifactURL(named: "\(name).png", for: testCase)
        
        // Create the directory if it doesn't exist
        let directoryURL = failedURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        // Save the image
        try? saveImage(image, to: failedURL)
        
        print("Saved failed test image: \(failedURL.path)")
    }
    
    /// Saves an image to a file
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: The URL to save the image to
    private static func saveImage(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
            throw NSError(domain: "VisualTestUtility", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "VisualTestUtility", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write image to file"])
        }
    }
    
    /// Loads an image from a file
    /// - Parameter url: The URL to load the image from
    /// - Returns: The loaded image, or nil if loading failed
    private static func loadImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
    
    // MARK: - Convenience Methods
    
    /// Checks if a reference image exists for a given test
    /// - Parameters:
    ///   - name: The name of the reference image
    ///   - testCase: The test case that's checking for the reference image
    /// - Returns: True if the reference image exists
    static func referenceImageExists(named name: String, for testCase: XCTestCase) -> Bool {
        let config = TestConfig.shared
        let referenceURL = config.referenceImageURL(named: name, for: testCase)
        return FileManager.default.fileExists(atPath: referenceURL.path)
    }
    
    /// Gets the URL for a reference image
    /// - Parameters:
    ///   - name: The name of the reference image
    ///   - testCase: The test case that's requesting the reference image
    /// - Returns: The URL for the reference image
    static func referenceImageURL(named name: String, for testCase: XCTestCase) -> URL {
        return TestConfig.shared.referenceImageURL(named: name, for: testCase)
    }
    
    /// Cleans up all failed test artifacts
    static func cleanupFailedTestArtifacts() {
        let config = TestConfig.shared
        try? FileManager.default.removeItem(at: config.failedTestArtifactsDir)
    }
} 