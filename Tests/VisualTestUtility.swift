import Foundation
import XCTest
import CoreGraphics
import CoreImage

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Utility for visual testing and image comparison.
/// Provides methods for comparing images, generating diff visualizations, and managing reference images.
public final class VisualTestUtility {
    
    /// Enum defining possible comparison results
    public enum ComparisonResult {
        case match
        case differ
        case referenceNotFound
    }
    
    /// Error types for visual testing
    public enum VisualTestError: Error, LocalizedError {
        /// Reference image not found
        case referenceImageNotFound(String)
        /// Failed to load reference image
        case referenceImageLoadFailed(String, Error)
        /// Failed to load actual image
        case actualImageLoadFailed(String, Error)
        /// Images have different dimensions
        case dimensionMismatch(expected: CGSize, actual: CGSize)
        /// Images have different pixel formats
        case formatMismatch(expected: String, actual: String)
        /// Image comparison failed
        case comparisonFailed(diff: Double)
        /// Failed to create diff image
        case diffImageCreationFailed(Error)
        
        public var errorDescription: String? {
            switch self {
            case .referenceImageNotFound(let name):
                return "Reference image not found: \(name)"
            case .referenceImageLoadFailed(let name, let error):
                return "Failed to load reference image '\(name)': \(error.localizedDescription)"
            case .actualImageLoadFailed(let name, let error):
                return "Failed to load actual image '\(name)': \(error.localizedDescription)"
            case .dimensionMismatch(let expected, let actual):
                return "Image dimensions don't match: expected \(expected), got \(actual)"
            case .formatMismatch(let expected, let actual):
                return "Image formats don't match: expected \(expected), got \(actual)"
            case .comparisonFailed(let diff):
                return "Images don't match: \(String(format: "%.2f%%", diff * 100)) of pixels differ"
            case .diffImageCreationFailed(let error):
                return "Failed to create diff image: \(error.localizedDescription)"
            }
        }
    }
    
    /// Options for image comparison
    public struct ComparisonOptions {
        /// Pixel tolerance as a percentage (0.0-1.0)
        public var pixelTolerance: Double = 0.02  // 2% tolerance by default
        /// Whether to ignore alpha channel
        public var ignoreAlpha: Bool = true
        /// Brightness tolerance for each channel (0-255)
        public var brightnessTolerance: UInt8 = 5
        /// Whether to use perceptual comparison (takes longer)
        public var perceptualComparison: Bool = false
        /// Whether to create a diff image on failure
        public var createDiffImage: Bool = true
        /// Whether to compare HDR content
        public var compareHDR: Bool = false
        /// HDR component tolerance (used when compareHDR = true)
        public var hdrTolerance: Double = 0.05
        
        /// Create with default settings
        public static var `default`: ComparisonOptions { ComparisonOptions() }
        
        /// Create a strict comparison (lower tolerance)
        public static var strict: ComparisonOptions {
            var options = ComparisonOptions()
            options.pixelTolerance = 0.005  // 0.5% tolerance
            options.brightnessTolerance = 2
            return options
        }
        
        /// Create settings for HDR content
        public static var hdr: ComparisonOptions {
            var options = ComparisonOptions()
            options.compareHDR = true
            options.perceptualComparison = true
            return options
        }
        
        /// Create with custom settings
        public init(
            pixelTolerance: Double = 0.02,
            ignoreAlpha: Bool = true,
            brightnessTolerance: UInt8 = 5,
            perceptualComparison: Bool = false,
            createDiffImage: Bool = true,
            compareHDR: Bool = false,
            hdrTolerance: Double = 0.05
        ) {
            self.pixelTolerance = pixelTolerance
            self.ignoreAlpha = ignoreAlpha
            self.brightnessTolerance = brightnessTolerance
            self.perceptualComparison = perceptualComparison
            self.createDiffImage = createDiffImage
            self.compareHDR = compareHDR
            self.hdrTolerance = hdrTolerance
        }
    }
    
    /// Result of an image comparison
    public struct ComparisonResult {
        /// Whether the comparison passed
        public let passed: Bool
        /// Difference percentage (0.0-1.0)
        public let difference: Double
        /// URL to the diff image (if created)
        public let diffImageURL: URL?
        /// Time taken for comparison in seconds
        public let comparisonTime: TimeInterval
        
        /// Create a successful result
        public static func success(difference: Double = 0.0, time: TimeInterval) -> ComparisonResult {
            return ComparisonResult(passed: true, difference: difference, diffImageURL: nil, comparisonTime: time)
        }
        
        /// Create a failure result
        public static func failure(difference: Double, diffImageURL: URL?, time: TimeInterval) -> ComparisonResult {
            return ComparisonResult(passed: false, difference: difference, diffImageURL: diffImageURL, comparisonTime: time)
        }
    }
    
    /// Shared instance of the visual test utility
    public static let shared = VisualTestUtility()
    
    /// Directory for reference images
    public var referenceImageDirectory: URL {
        return TestConfig.shared.referenceImagesDir
    }
    
    /// Directory for failed tests to store differences
    public var failedTestsDirectory: URL {
        return TestConfig.shared.failedImagesDir
    }
    
    /// Verify that the actual image matches the reference image
    /// - Parameters:
    ///   - actualImage: The image to test
    ///   - referenceImageName: Name of the reference image without extension
    ///   - testName: Name of the test (used for storing results)
    ///   - options: Comparison options (defaults to default options)
    /// - Returns: Comparison result
    /// - Throws: VisualTestError if the verification fails
    @discardableResult
    public func verifyImage(
        _ actualImage: CGImage,
        matchesReferenceNamed referenceImageName: String,
        testName: String,
        options: ComparisonOptions = .default
    ) throws -> ComparisonResult {
        let startTime = Date()
        
        // Get reference image path
        let referenceImageExtension = "png"
        let referenceImageURL = referenceImageDirectory.appendingPathComponent("\(referenceImageName).\(referenceImageExtension)")
        
        // Check if reference image exists, if not, save the current image as reference
        if !FileManager.default.fileExists(atPath: referenceImageURL.path) {
            // Create reference directory if needed
            try FileManager.default.createDirectory(
                at: referenceImageDirectory,
                withIntermediateDirectories: true
            )
            
            // Save the current image as reference
            try saveImage(actualImage, to: referenceImageURL)
            
            // Log that we created a reference image
            print("⚠️ Created reference image: \(referenceImageName)")
            
            // Return success as we just created the reference
            return .success(time: Date().timeIntervalSince(startTime))
        }
        
        // Load reference image
        guard let referenceImage = loadImage(from: referenceImageURL) else {
            throw VisualTestError.referenceImageLoadFailed(referenceImageName, NSError(domain: "VisualTestUtility", code: 1, userInfo: nil))
        }
        
        // Compare images
        let result = try compareImages(
            actual: actualImage,
            reference: referenceImage,
            testName: testName,
            options: options
        )
        
        // Handle failures
        if !result.passed {
            throw VisualTestError.comparisonFailed(diff: result.difference)
        }
        
        return result
    }
    
    /// Compare two images and generate a comparison result
    /// - Parameters:
    ///   - actual: The actual image
    ///   - reference: The reference image
    ///   - testName: Name of the test (used for storing results)
    ///   - options: Comparison options
    /// - Returns: Comparison result
    /// - Throws: VisualTestError if the comparison fails
    public func compareImages(
        actual: CGImage,
        reference: CGImage,
        testName: String,
        options: ComparisonOptions
    ) throws -> ComparisonResult {
        let startTime = Date()
        
        // Check dimensions
        if actual.width != reference.width || actual.height != reference.height {
            throw VisualTestError.dimensionMismatch(
                expected: CGSize(width: reference.width, height: reference.height),
                actual: CGSize(width: actual.width, height: actual.height)
            )
        }
        
        // Create a bitmap context for comparison
        let width = actual.width
        let height = actual.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var differentPixels = 0
        var diffImage: CGImage?
        var diffData: UnsafeMutablePointer<UInt8>?
        
        // Allocate memory for pixel data
        guard let actualData = getCGImageData(actual) else {
            throw VisualTestError.actualImageLoadFailed("actual", NSError(domain: "VisualTestUtility", code: 2, userInfo: nil))
        }
        defer { free(actualData) }
        
        guard let referenceData = getCGImageData(reference) else {
            throw VisualTestError.referenceImageLoadFailed("reference", NSError(domain: "VisualTestUtility", code: 3, userInfo: nil))
        }
        defer { free(referenceData) }
        
        // Create diff buffer if needed
        if options.createDiffImage {
            diffData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)
            defer { diffData?.deallocate() }
            
            // Initialize to all white
            memset(diffData, 255, width * height * bytesPerPixel)
        }
        
        // Compare pixels
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let referenceR = referenceData[pixelIndex]
                let referenceG = referenceData[pixelIndex + 1]
                let referenceB = referenceData[pixelIndex + 2]
                let referenceA = options.ignoreAlpha ? 255 : referenceData[pixelIndex + 3]
                
                let actualR = actualData[pixelIndex]
                let actualG = actualData[pixelIndex + 1]
                let actualB = actualData[pixelIndex + 2]
                let actualA = options.ignoreAlpha ? 255 : actualData[pixelIndex + 3]
                
                // Check if pixels are different
                let isPixelDifferent = isPixelDifferent(
                    r1: referenceR, g1: referenceG, b1: referenceB, a1: referenceA,
                    r2: actualR, g2: actualG, b2: actualB, a2: actualA,
                    options: options
                )
                
                if isPixelDifferent {
                    differentPixels += 1
                    
                    // Mark the diff image
                    if options.createDiffImage, let diffData = diffData {
                        // Mark with red
                        diffData[pixelIndex] = 255     // R
                        diffData[pixelIndex + 1] = 0   // G
                        diffData[pixelIndex + 2] = 0   // B
                        diffData[pixelIndex + 3] = 255 // A
                    }
                } else if options.createDiffImage, let diffData = diffData {
                    // Copy the actual pixel to the diff image
                    diffData[pixelIndex] = actualR
                    diffData[pixelIndex + 1] = actualG
                    diffData[pixelIndex + 2] = actualB
                    diffData[pixelIndex + 3] = actualA
                }
            }
        }
        
        // Calculate difference percentage
        let totalPixels = width * height
        let difference = Double(differentPixels) / Double(totalPixels)
        
        // Check if the comparison passed
        let passed = difference <= options.pixelTolerance
        
        // Create and save diff image if needed
        var diffImageURL: URL?
        if !passed && options.createDiffImage {
            // Create directory if needed
            try FileManager.default.createDirectory(
                at: failedTestsDirectory,
                withIntermediateDirectories: true
            )
            
            // Create diff image
            if let diffData = diffData {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                
                if let diffContext = CGContext(
                    data: diffData,
                    width: width,
                    height: height,
                    bitsPerComponent: bitsPerComponent,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ), let diffCGImage = diffContext.makeImage() {
                    diffImage = diffCGImage
                    
                    // Save the diff image
                    let timestamp = Int(Date().timeIntervalSince1970)
                    diffImageURL = failedTestsDirectory.appendingPathComponent("\(testName)_diff_\(timestamp).png")
                    
                    try saveImage(diffCGImage, to: diffImageURL!)
                }
            }
        }
        
        // Create comparison result
        let comparisonTime = Date().timeIntervalSince(startTime)
        return passed
            ? .success(difference: difference, time: comparisonTime)
            : .failure(difference: difference, diffImageURL: diffImageURL, time: comparisonTime)
    }
    
    // MARK: - Helper Methods
    
    /// Check if two pixels are different
    private func isPixelDifferent(
        r1: UInt8, g1: UInt8, b1: UInt8, a1: UInt8,
        r2: UInt8, g2: UInt8, b2: UInt8, a2: UInt8,
        options: ComparisonOptions
    ) -> Bool {
        // Alpha difference
        if !options.ignoreAlpha && abs(Int(a1) - Int(a2)) > Int(options.brightnessTolerance) {
            return true
        }
        
        if options.perceptualComparison {
            // Convert to Lab color space for perceptual comparison
            let lab1 = rgbToLab(r: r1, g: g1, b: b1)
            let lab2 = rgbToLab(r: r2, g: g2, b: b2)
            
            // Calculate deltaE (color difference)
            let deltaE = sqrt(
                pow(lab1.l - lab2.l, 2) +
                pow(lab1.a - lab2.a, 2) +
                pow(lab1.b - lab2.b, 2)
            )
            
            // DeltaE of 2.3 is just noticeable difference
            return deltaE > 2.3
        } else {
            // Simple RGB comparison
            let rDiff = abs(Int(r1) - Int(r2))
            let gDiff = abs(Int(g1) - Int(g2))
            let bDiff = abs(Int(b1) - Int(b2))
            
            return rDiff > Int(options.brightnessTolerance) ||
                   gDiff > Int(options.brightnessTolerance) ||
                   bDiff > Int(options.brightnessTolerance)
        }
    }
    
    /// Get a pointer to CGImage's raw data
    private func getCGImageData(_ image: CGImage) -> UnsafeMutablePointer<UInt8>? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        // Allocate memory for pixel data
        let data = malloc(width * height * bytesPerPixel)
        
        // Create a context to draw the image
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            free(data)
            return nil
        }
        
        // Draw the image to the context
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        
        return data?.assumingMemoryBound(to: UInt8.self)
    }
    
    /// Convert RGB to Lab color space
    private func rgbToLab(r: UInt8, g: UInt8, b: UInt8) -> (l: Double, a: Double, b: Double) {
        // Convert RGB to XYZ
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0
        
        // Apply gamma correction
        let r1 = rf > 0.04045 ? pow((rf + 0.055) / 1.055, 2.4) : rf / 12.92
        let g1 = gf > 0.04045 ? pow((gf + 0.055) / 1.055, 2.4) : gf / 12.92
        let b1 = bf > 0.04045 ? pow((bf + 0.055) / 1.055, 2.4) : bf / 12.92
        
        // Convert to XYZ
        let x = r1 * 0.4124 + g1 * 0.3576 + b1 * 0.1805
        let y = r1 * 0.2126 + g1 * 0.7152 + b1 * 0.0722
        let z = r1 * 0.0193 + g1 * 0.1192 + b1 * 0.9505
        
        // Convert XYZ to Lab
        let xr = x / 0.95047
        let yr = y / 1.0
        let zr = z / 1.08883
        
        let fx = xr > 0.008856 ? pow(xr, 1.0/3.0) : (7.787 * xr) + (16.0/116.0)
        let fy = yr > 0.008856 ? pow(yr, 1.0/3.0) : (7.787 * yr) + (16.0/116.0)
        let fz = zr > 0.008856 ? pow(zr, 1.0/3.0) : (7.787 * zr) + (16.0/116.0)
        
        let l = (116.0 * fy) - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)
        
        return (l: l, a: a, b: b)
    }
    
    /// Load an image from a URL
    private func loadImage(from url: URL) -> CGImage? {
        #if os(macOS)
        if let nsImage = NSImage(contentsOf: url) {
            var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
            return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        }
        #elseif os(iOS)
        if let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage.cgImage
        }
        #endif
        return nil
    }
    
    /// Save an image to a URL
    private func saveImage(_ image: CGImage, to url: URL) throws {
        #if os(macOS)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        guard let data = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw VisualTestError.diffImageCreationFailed(NSError(domain: "VisualTestUtility", code: 4, userInfo: nil))
        }
        
        try pngData.write(to: url)
        #elseif os(iOS)
        let uiImage = UIImage(cgImage: image)
        
        guard let data = uiImage.pngData() else {
            throw VisualTestError.diffImageCreationFailed(NSError(domain: "VisualTestUtility", code: 4, userInfo: nil))
        }
        
        try data.write(to: url)
        #endif
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    /// Compare an image with a reference image
    /// - Parameters:
    ///   - image: The image to test
    ///   - referenceNamed: Base name of the reference image
    ///   - options: Comparison options (defaults to default options)
    /// - Throws: VisualTestError if the comparison fails
    public func assertImage(
        _ image: CGImage,
        matchesReferenceNamed referenceNamed: String,
        options: VisualTestUtility.ComparisonOptions = .default
    ) throws {
        // Get the test name
        let testName = String(reflecting: type(of: self)) + "." + name
        
        try VisualTestUtility.shared.verifyImage(
            image,
            matchesReferenceNamed: referenceNamed,
            testName: testName,
            options: options
        )
    }
    
    /// Compare an image with a reference image for HDR content
    /// - Parameters:
    ///   - image: The HDR image to test
    ///   - referenceNamed: Base name of the reference image
    /// - Throws: VisualTestError if the comparison fails
    public func assertHDRImage(
        _ image: CGImage,
        matchesReferenceNamed referenceNamed: String
    ) throws {
        try assertImage(
            image,
            matchesReferenceNamed: referenceNamed,
            options: .hdr
        )
    }
} 