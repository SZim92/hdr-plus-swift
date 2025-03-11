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
    ) -> (matches: Bool, diffPercentage: Float) {
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
        // Ensure images are the same size, or resize them
        let size = image1.size
        
        guard let data1 = convertToBitmapData(image1),
              let data2 = convertToBitmapData(image2) else {
            return nil
        }
        
        // Create a new image for the diff
        let diffImage = NSImage(size: size)
        diffImage.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            diffImage.unlockFocus()
            return nil
        }
        
        // Create a bitmap for the diff
        let width = Int(size.width)
        let height = Int(size.height)
        var diffData = [UInt8](repeating: 0, count: width * height * 4)
        
        // Calculate difference for each pixel
        for i in stride(from: 0, to: min(data1.count, data2.count), by: 4) {
            // Calculate difference magnitude
            let r1 = Float(data1[i])
            let g1 = Float(data1[i+1])
            let b1 = Float(data1[i+2])
            
            let r2 = Float(data2[i])
            let g2 = Float(data2[i+1])
            let b2 = Float(data2[i+2])
            
            // Calculate diff values - show in red for better visibility
            let diffR = UInt8(min(255, abs(r1 - r2) * 4)) // Amplify difference for visibility
            let diffG = UInt8(min(255, abs(g1 - g2) * 4))
            let diffB = UInt8(min(255, abs(b1 - b2) * 4))
            
            // We'll use a heat map: black means no difference, red/yellow/white means increasing difference
            let diffMagnitude = max(diffR, diffG, diffB)
            
            if diffMagnitude > 0 {
                // Create a heat map effect
                diffData[i] = diffMagnitude
                diffData[i+1] = diffMagnitude > 128 ? UInt8(diffMagnitude - 128) * 2 : 0 // Yellow for larger diffs
                diffData[i+2] = 0 // No blue
                diffData[i+3] = 255 // Fully opaque
            } else {
                // No difference - show original image in grayscale at 50% opacity
                let gray = UInt8((r1 * 0.299 + g1 * 0.587 + b1 * 0.114) / 4)
                diffData[i] = gray
                diffData[i+1] = gray
                diffData[i+2] = gray 
                diffData[i+3] = 128 // Semi-transparent
            }
        }
        
        // Create a CGImage from our diff data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let provider = CGDataProvider(data: Data(bytes: diffData, count: diffData.count) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            diffImage.unlockFocus()
            return nil
        }
        
        // Draw the CGImage in our context
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        diffImage.unlockFocus()
        
        return diffImage
    }
    
    /// Saves an image to disk at the specified URL with the given filename
    private static func saveImage(_ image: NSImage, to directory: URL, fileName: String) {
        // Ensure the directory exists
        ensureDirectoryExists(directory)
        
        // Create final URL for the image
        let fileURL = directory.appendingPathComponent("\(fileName).png")
        
        // Convert to PNG and save
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("⚠️ Failed to convert image to PNG")
            return
        }
        
        do {
            try pngData.write(to: fileURL)
        } catch {
            print("⚠️ Failed to save image to \(fileURL.path): \(error.localizedDescription)")
        }
    }
    
    /// Ensures a directory exists, creating it if necessary
    private static func ensureDirectoryExists(_ url: URL) {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print("⚠️ Failed to create directory at \(url.path): \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets the URL for the reference images directory for a test class
    private static func referenceDirectoryURL(testClass: AnyClass) -> URL {
        let bundle = Bundle(for: testClass)
        let testModuleName = String(describing: testClass).components(separatedBy: ".").first ?? "TestModule"
        
        // First try the standard location
        let standardPath = bundle.bundleURL.appendingPathComponent(referenceImageDirectory)
                               .appendingPathComponent(testModuleName)
        
        // If we're running in an Xcode environment, try a different path
        if !FileManager.default.fileExists(atPath: standardPath.path) {
            // Try to find the project directory
            let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] ?? ""
            if !sourceRoot.isEmpty {
                let projectPath = URL(fileURLWithPath: sourceRoot)
                                    .appendingPathComponent("Tests")
                                    .appendingPathComponent("TestResources")
                                    .appendingPathComponent(referenceImageDirectory)
                                    .appendingPathComponent(testModuleName)
                return projectPath
            }
        }
        
        return standardPath
    }
    
    /// Gets the URL for a reference file
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