import Foundation
import XCTest
import CoreGraphics
import CoreImage

/// Utility for visual testing and image comparison.
/// Provides methods for comparing images, generating diff visualizations, and managing reference images.
public final class VisualTestUtility {
    
    /// Enum defining possible comparison results
    public enum ComparisonResult {
        case match
        case differ
        case referenceNotFound
    }
    
    /// Compare an image against a reference image.
    /// If the reference image doesn't exist and auto-update is enabled, the test image becomes the new reference.
    /// If the images differ and saving is enabled, the test image and diff image are saved to the failed artifacts directory.
    ///
    /// - Parameters:
    ///   - image: The test image to compare.
    ///   - referenceName: The name of the reference image (without extension).
    ///   - tolerance: The maximum acceptable percentage of pixels that can differ (0.0 to 1.0).
    ///   - testCase: The test case requesting the comparison.
    /// - Returns: true if the images match within tolerance, false otherwise.
    @discardableResult
    public static func compareImage(
        _ image: CGImage,
        toReferenceNamed referenceName: String,
        tolerance: Double = TestConfig.shared.defaultImageComparisonTolerance,
        in testCase: XCTestCase
    ) -> Bool {
        let testClass = type(of: testCase)
        let referenceURL = TestConfig.shared.referenceImageURL(for: referenceName, in: testClass)
        
        // Get directory for reference image
        let referenceDir = referenceURL.deletingLastPathComponent()
        do {
            if !FileManager.default.fileExists(atPath: referenceDir.path) {
                try FileManager.default.createDirectory(at: referenceDir, withIntermediateDirectories: true)
            }
        } catch {
            XCTFail("Failed to create reference directory: \(error)")
            return false
        }
        
        // Check if reference image exists
        let referenceExists = FileManager.default.fileExists(atPath: referenceURL.path)
        
        if !referenceExists {
            if TestConfig.shared.updateReferenceImagesAutomatically {
                // Save current image as reference
                if saveImage(image, to: referenceURL) {
                    print("Created new reference image at \(referenceURL.path)")
                    return true
                } else {
                    XCTFail("Failed to create reference image at \(referenceURL.path)")
                    return false
                }
            } else {
                XCTFail("Reference image doesn't exist at \(referenceURL.path) and auto-update is disabled")
                return false
            }
        }
        
        // Load reference image
        guard let referenceImage = loadImage(from: referenceURL) else {
            XCTFail("Failed to load reference image from \(referenceURL.path)")
            return false
        }
        
        // Compare images
        let (match, diffImage, diffPercentage) = compareImages(image, referenceImage, tolerance: tolerance)
        
        // If images don't match and saving is enabled, save the failed test and diff images
        if !match && TestConfig.shared.saveFailedVisualTests {
            // Save test image
            let failedTestURL = TestConfig.shared.failedTestArtifactURL(for: referenceName, in: testClass)
            
            // Create directory for failed test artifact
            let failedDir = failedTestURL.deletingLastPathComponent()
            do {
                if !FileManager.default.fileExists(atPath: failedDir.path) {
                    try FileManager.default.createDirectory(at: failedDir, withIntermediateDirectories: true)
                }
            } catch {
                XCTFail("Failed to create directory for failed test: \(error)")
            }
            
            // Save test image
            if !saveImage(image, to: failedTestURL) {
                XCTFail("Failed to save test image to \(failedTestURL.path)")
            }
            
            // Save diff image if available
            if let diffImage = diffImage {
                let diffURL = failedTestURL.deletingLastPathComponent()
                    .appendingPathComponent("\(referenceName)_diff.png")
                if !saveImage(diffImage, to: diffURL) {
                    XCTFail("Failed to save diff image to \(diffURL.path)")
                }
            }
            
            print("Images differ by \(diffPercentage * 100)% (tolerance: \(tolerance * 100)%)")
            print("Failed test image saved to \(failedTestURL.path)")
        }
        
        return match
    }
    
    /// Compare two images and generate a diff image.
    /// - Parameters:
    ///   - image1: The first image to compare.
    ///   - image2: The second image to compare.
    ///   - tolerance: The maximum acceptable percentage of pixels that can differ (0.0 to 1.0).
    /// - Returns: A tuple containing (match, diffImage, diffPercentage).
    private static func compareImages(
        _ image1: CGImage,
        _ image2: CGImage,
        tolerance: Double
    ) -> (Bool, CGImage?, Double) {
        // Check if dimensions match
        guard image1.width == image2.width, image1.height == image2.height else {
            print("Image dimensions don't match: \(image1.width)x\(image1.height) vs \(image2.width)x\(image2.height)")
            return (false, nil, 1.0)
        }
        
        // Create contexts for both images
        guard let data1 = createRGBAData(from: image1),
              let data2 = createRGBAData(from: image2) else {
            print("Failed to create RGBA data for images")
            return (false, nil, 1.0)
        }
        
        // Create diff image data
        let width = image1.width
        let height = image1.height
        let pixelCount = width * height
        let bytesPerPixel = 4
        let diffData = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
        
        // Count differing pixels
        var differentPixels = 0
        for i in 0..<pixelCount {
            let baseIndex = i * bytesPerPixel
            
            let r1 = data1[baseIndex]
            let g1 = data1[baseIndex + 1]
            let b1 = data1[baseIndex + 2]
            let a1 = data1[baseIndex + 3]
            
            let r2 = data2[baseIndex]
            let g2 = data2[baseIndex + 1]
            let b2 = data2[baseIndex + 2]
            let a2 = data2[baseIndex + 3]
            
            if r1 != r2 || g1 != g2 || b1 != b2 || a1 != a2 {
                differentPixels += 1
                
                // Highlight difference in red
                diffData[baseIndex] = 255      // R
                diffData[baseIndex + 1] = 0    // G
                diffData[baseIndex + 2] = 0    // B
                diffData[baseIndex + 3] = 255  // A
            } else {
                // Keep original pixel
                diffData[baseIndex] = r1       // R
                diffData[baseIndex + 1] = g1   // G
                diffData[baseIndex + 2] = b1   // B
                diffData[baseIndex + 3] = a1   // A
            }
        }
        
        // Calculate difference percentage
        let diffPercentage = Double(differentPixels) / Double(pixelCount)
        
        // Create diff image
        let diffImage = createImage(from: diffData, width: width, height: height)
        
        // Free memory
        data1.deallocate()
        data2.deallocate()
        diffData.deallocate()
        
        return (diffPercentage <= tolerance, diffImage, diffPercentage)
    }
    
    /// Load an image from a file URL.
    /// - Parameter url: The URL of the image file.
    /// - Returns: A CGImage if successful, nil otherwise.
    private static func loadImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        return image
    }
    
    /// Save a CGImage to a file URL.
    /// - Parameters:
    ///   - image: The image to save.
    ///   - url: The URL to save the image to.
    /// - Returns: true if saving was successful, false otherwise.
    @discardableResult
    private static func saveImage(_ image: CGImage, to url: URL) -> Bool {
        let fileURL = url as CFURL
        guard let destination = CGImageDestinationCreateWithURL(fileURL, kUTTypePNG, 1, nil) else {
            return false
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    
    /// Create RGBA data from a CGImage.
    /// - Parameter image: The source image.
    /// - Returns: A pointer to the RGBA data if successful, nil otherwise.
    private static func createRGBAData(from image: CGImage) -> UnsafeMutablePointer<UInt8>? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            data.deallocate()
            return nil
        }
        
        // Draw image to context
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        
        return data
    }
    
    /// Create a CGImage from RGBA data.
    /// - Parameters:
    ///   - data: The RGBA pixel data.
    ///   - width: The width of the image.
    ///   - height: The height of the image.
    /// - Returns: A CGImage if successful, nil otherwise.
    private static func createImage(from data: UnsafeMutablePointer<UInt8>, width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            return nil
        }
        
        return image
    }
    
    // MARK: - Test Image Generation
    
    /// Create a gradient test image.
    /// - Parameters:
    ///   - width: The width of the image.
    ///   - height: The height of the image.
    ///   - startColor: The start color as (red, green, blue) tuple, values from 0.0 to 1.0.
    ///   - endColor: The end color as (red, green, blue) tuple, values from 0.0 to 1.0.
    ///   - direction: The direction of the gradient, "horizontal" or "vertical".
    /// - Returns: A CGImage containing the gradient.
    public static func createGradientImage(
        width: Int,
        height: Int,
        startColor: (red: Double, green: Double, blue: Double),
        endColor: (red: Double, green: Double, blue: Double),
        direction: String = "horizontal"
    ) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let pixelCount = width * height
        
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
        defer { data.deallocate() }
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel
                
                // Calculate gradient factor (0.0 to 1.0)
                let factor: Double
                if direction == "vertical" {
                    factor = Double(y) / Double(height - 1)
                } else {
                    factor = Double(x) / Double(width - 1)
                }
                
                // Interpolate colors
                let r = startColor.red + (endColor.red - startColor.red) * factor
                let g = startColor.green + (endColor.green - startColor.green) * factor
                let b = startColor.blue + (endColor.blue - startColor.blue) * factor
                
                // Set pixel values
                data[index] = UInt8(r * 255.0)
                data[index + 1] = UInt8(g * 255.0)
                data[index + 2] = UInt8(b * 255.0)
                data[index + 3] = 255 // Alpha
            }
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            return nil
        }
        
        return image
    }
    
    /// Create a checkerboard test image.
    /// - Parameters:
    ///   - width: The width of the image.
    ///   - height: The height of the image.
    ///   - squareSize: The size of each checkerboard square.
    ///   - color1: The first color as (red, green, blue) tuple, values from 0.0 to 1.0.
    ///   - color2: The second color as (red, green, blue) tuple, values from 0.0 to 1.0.
    /// - Returns: A CGImage containing the checkerboard.
    public static func createCheckerboardImage(
        width: Int,
        height: Int,
        squareSize: Int = 16,
        color1: (red: Double, green: Double, blue: Double) = (0.0, 0.0, 0.0),
        color2: (red: Double, green: Double, blue: Double) = (1.0, 1.0, 1.0)
    ) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let pixelCount = width * height
        
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
        defer { data.deallocate() }
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel
                
                // Determine if this is color1 or color2 based on checkerboard pattern
                let isColor1 = ((x / squareSize) + (y / squareSize)) % 2 == 0
                let color = isColor1 ? color1 : color2
                
                // Set pixel values
                data[index] = UInt8(color.red * 255.0)
                data[index + 1] = UInt8(color.green * 255.0)
                data[index + 2] = UInt8(color.blue * 255.0)
                data[index + 3] = 255 // Alpha
            }
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            return nil
        }
        
        return image
    }
    
    /// Create a test image with a grid of color patches.
    /// - Parameters:
    ///   - width: The width of the image.
    ///   - height: The height of the image.
    ///   - columns: The number of color columns.
    ///   - rows: The number of color rows.
    /// - Returns: A CGImage containing the color patches.
    public static func createColorPatchesImage(
        width: Int,
        height: Int,
        columns: Int = 4,
        rows: Int = 4
    ) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let pixelCount = width * height
        
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
        defer { data.deallocate() }
        
        let patchWidth = width / columns
        let patchHeight = height / rows
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel
                
                let col = x / patchWidth
                let row = y / patchHeight
                
                // Calculate color based on position
                let r = Double(col) / Double(columns - 1)
                let g = Double(row) / Double(rows - 1)
                let b = 0.5
                
                // Set pixel values
                data[index] = UInt8(r * 255.0)
                data[index + 1] = UInt8(g * 255.0)
                data[index + 2] = UInt8(b * 255.0)
                data[index + 3] = 255 // Alpha
            }
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            return nil
        }
        
        return image
    }
    
    /// Create a simulated HDR image with overexposed and underexposed areas.
    /// - Parameters:
    ///   - width: The width of the image.
    ///   - height: The height of the image.
    ///   - dynamicRange: The simulated dynamic range (higher values create more contrast).
    /// - Returns: A CGImage simulating an HDR scene.
    public static func createHDRTestImage(
        width: Int,
        height: Int,
        dynamicRange: Double = 5.0
    ) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let pixelCount = width * height
        
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount * bytesPerPixel)
        defer { data.deallocate() }
        
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0
        let maxRadius = min(Double(width), Double(height)) / 2.0
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel
                
                // Create a radial gradient with some high contrast areas
                let dx = Double(x) - centerX
                let dy = Double(y) - centerY
                let distance = sqrt(dx * dx + dy * dy) / maxRadius
                
                // Create some high dynamic range by having very bright and very dark areas
                let angle = atan2(dy, dx)
                let angleFactor = (sin(angle * 5.0) + 1.0) / 2.0
                
                // Adjust intensity based on dynamic range
                let intensity = pow(distance, dynamicRange) * angleFactor
                
                // Simulate bright spot in center
                let brightSpot = max(0.0, 1.0 - distance * 3.0)
                let brightFactor = brightSpot * brightSpot * 2.0
                
                // Set pixel values with some areas being very bright (simulating overexposure)
                let r = min(1.0, intensity + brightFactor)
                let g = min(1.0, intensity * 0.8 + brightFactor * 0.7)
                let b = min(1.0, intensity * 0.6 + brightFactor * 0.5)
                
                data[index] = UInt8(r * 255.0)
                data[index + 1] = UInt8(g * 255.0)
                data[index + 2] = UInt8(b * 255.0)
                data[index + 3] = 255 // Alpha
            }
        }
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            return nil
        }
        
        return image
    }
} 