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
    public enum ComparisonStatus {
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
                return "Images differ by \(String(format: "%.2f", diff))%"
            case .diffImageCreationFailed(let error):
                return "Failed to create diff image: \(error.localizedDescription)"
            }
        }
    }
    
    /// Options for image comparison
    public struct ComparisonOptions {
        /// Threshold for considering images as matching (0.0 - 100.0)
        public let threshold: Double
        /// Whether to generate a diff image for failed comparisons
        public let generateDiffImage: Bool
        /// Directory for storing diff images
        public let diffDirectory: URL?
        
        /// Initialize with default options
        public init(
            threshold: Double = 0.1,
            generateDiffImage: Bool = true,
            diffDirectory: URL? = nil
        ) {
            self.threshold = threshold
            self.generateDiffImage = generateDiffImage
            self.diffDirectory = diffDirectory
        }
    }
    
    /// Result of image comparison
    public struct ComparisonResult {
        /// Whether the comparison passed
        public let passed: Bool
        /// Percentage difference between images (0.0 - 100.0)
        public let difference: Double
        /// URL to the diff image if generated
        public let diffImageURL: URL?
        /// Time taken for comparison
        public let comparisonTime: TimeInterval
        
        /// Create a success result
        public static func success(difference: Double = 0.0, time: TimeInterval) -> VisualTestUtility.ComparisonResult {
            return VisualTestUtility.ComparisonResult(passed: true, difference: difference, diffImageURL: nil, comparisonTime: time)
        }
        
        /// Create a failure result
        public static func failure(difference: Double, diffImageURL: URL?, time: TimeInterval) -> VisualTestUtility.ComparisonResult {
            return VisualTestUtility.ComparisonResult(passed: false, difference: difference, diffImageURL: diffImageURL, comparisonTime: time)
        }
    }
    
    /// Shared instance
    public static let shared = VisualTestUtility()
    
    /// Directory for reference images
    private let referenceImagesDirectory: URL?
    
    /// Initialize with default reference directory
    public init(referenceImagesDirectory: URL? = nil) {
        self.referenceImagesDirectory = referenceImagesDirectory
    }
    
    /// Verify an image against a reference image
    /// - Parameters:
    ///   - image: The image to verify
    ///   - referenceImage: Optional reference image, if nil will be loaded from disk
    ///   - testName: Name of the test (used for storing results)
    ///   - options: Comparison options
    /// - Returns: Comparison result
    /// - Throws: VisualTestError if the comparison fails
    public func verifyImage(
        image: CGImage,
        referenceImage: CGImage? = nil,
        testName: String,
        options: ComparisonOptions = ComparisonOptions()
    ) throws -> VisualTestUtility.ComparisonResult {
        // If reference image not provided, load from disk
        let reference: CGImage
        if let referenceImage = referenceImage {
            reference = referenceImage
        } else {
            guard let referenceImagesDirectory = referenceImagesDirectory else {
                throw VisualTestError.referenceImageNotFound(testName)
            }
            
            let referenceURL = referenceImagesDirectory.appendingPathComponent("\(testName).png")
            
            guard let data = try? Data(contentsOf: referenceURL) else {
                throw VisualTestError.referenceImageNotFound(testName)
            }
            
            guard let provider = CGDataProvider(data: data as CFData),
                  let loadedReference = CGImage(
                    pngDataProviderSource: provider,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent
                  ) else {
                throw VisualTestError.referenceImageLoadFailed(testName, NSError(domain: "VisualTestUtility", code: 1, userInfo: nil))
            }
            
            reference = loadedReference
        }
        
        // Compare images
        let result = try compareImages(
            actual: image,
            reference: reference,
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
    ) throws -> VisualTestUtility.ComparisonResult {
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
        
        // If generating diff image, allocate memory for it
        if options.generateDiffImage {
            diffData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)
            defer { diffData?.deallocate() }
            
            // Initialize diff image with white
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * bytesPerPixel
                    diffData?[pixelIndex] = 255     // R
                    diffData?[pixelIndex + 1] = 255 // G
                    diffData?[pixelIndex + 2] = 255 // B
                    diffData?[pixelIndex + 3] = 255 // A
                }
            }
        }
        
        // Compare pixels
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let actualR = actualData[pixelIndex]
                let actualG = actualData[pixelIndex + 1]
                let actualB = actualData[pixelIndex + 2]
                let actualA = actualData[pixelIndex + 3]
                
                let referenceR = referenceData[pixelIndex]
                let referenceG = referenceData[pixelIndex + 1]
                let referenceB = referenceData[pixelIndex + 2]
                let referenceA = referenceData[pixelIndex + 3]
                
                // Check if pixels differ
                if actualR != referenceR || actualG != referenceG || actualB != referenceB || actualA != referenceA {
                    differentPixels += 1
                    
                    // Mark different pixels in diff image
                    if options.generateDiffImage, let diffData = diffData {
                        diffData[pixelIndex] = 255     // R (red)
                        diffData[pixelIndex + 1] = 0   // G
                        diffData[pixelIndex + 2] = 0   // B
                        diffData[pixelIndex + 3] = 255 // A
                    }
                }
            }
        }
        
        // Calculate difference percentage
        let totalPixels = width * height
        let differencePercentage = Double(differentPixels) / Double(totalPixels) * 100.0
        
        // Create diff image if needed
        var diffImageURL: URL?
        if options.generateDiffImage && differencePercentage > options.threshold, let diffData = diffData {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            
            if let context = CGContext(
                data: diffData,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ), let cgImage = context.makeImage() {
                diffImage = cgImage
                
                // Save diff image if directory provided
                if let diffDirectory = options.diffDirectory {
                    let fileManager = FileManager.default
                    
                    // Create directory if it doesn't exist
                    if !fileManager.fileExists(atPath: diffDirectory.path) {
                        try? fileManager.createDirectory(at: diffDirectory, withIntermediateDirectories: true)
                    }
                    
                    let diffURL = diffDirectory.appendingPathComponent("\(testName)_diff.png")
                    diffImageURL = diffURL
                    
                    #if os(macOS)
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
                    if let pngData = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: pngData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: diffURL)
                    }
                    #elseif os(iOS)
                    if let uiImage = UIImage(cgImage: cgImage) {
                        if let pngData = uiImage.pngData() {
                            try? pngData.write(to: diffURL)
                        }
                    }
                    #endif
                }
            }
        }
        
        let endTime = Date()
        let comparisonTime = endTime.timeIntervalSince(startTime)
        
        // Create result
        let passed = differencePercentage <= options.threshold
        let result = VisualTestUtility.ComparisonResult(
            passed: passed,
            difference: differencePercentage,
            diffImageURL: diffImageURL,
            comparisonTime: comparisonTime
        )
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Get raw pixel data from a CGImage
    private func getCGImageData(_ image: CGImage) -> UnsafeMutablePointer<UInt8>? {
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
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        
        return data
    }
} 