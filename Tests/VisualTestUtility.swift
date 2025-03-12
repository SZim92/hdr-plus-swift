import Foundation
import XCTest
import CoreGraphics
import CoreImage

/// Utility for comparing images in visual regression tests.
/// This provides methods to compare generated images with reference images,
/// and handle the saving of reference images if they don't exist.
public class VisualTestUtility {
    
    // MARK: - Image Comparison
    
    /// Compares a test image to a reference image
    /// - Parameters:
    ///   - image: The test image to compare
    ///   - referenceNamed: The name of the reference image
    ///   - tolerance: The maximum allowed difference between pixels (0.0-1.0)
    ///   - testCase: The test case that's performing the comparison
    /// - Returns: True if the images match within the tolerance
    @discardableResult
    public static func compareImage(
        _ image: CGImage,
        toReferenceNamed referenceNamed: String,
        tolerance: Double = TestConfig.shared.defaultImageComparisonTolerance,
        in testCase: XCTestCase
    ) -> Bool {
        let testClass = type(of: testCase)
        let testName = testCase.name
        
        // Create a unique name for this test case and reference image
        let referenceImageName = "\(referenceNamed)"
        
        // Get URLs for reference, failed, and diff images
        let config = TestConfig.shared
        let referenceImageURL = config.referenceImageURL(for: referenceImageName, in: testClass)
        let failedImageURL = config.failedImageURL(for: referenceImageName, in: testClass)
        let diffImageURL = config.diffImageURL(for: referenceImageName, in: testClass)
        
        // Create directories if they don't exist
        let referenceDir = referenceImageURL.deletingLastPathComponent()
        let failedDir = failedImageURL.deletingLastPathComponent()
        let diffDir = diffImageURL.deletingLastPathComponent()
        
        try? FileManager.default.createDirectory(at: referenceDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: failedDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: diffDir, withIntermediateDirectories: true)
        
        // If reference image doesn't exist, save this one and return success
        if !FileManager.default.fileExists(atPath: referenceImageURL.path) {
            config.logVerbose("Reference image doesn't exist, saving current image as reference: \(referenceImageURL.path)")
            saveImage(image, to: referenceImageURL)
            return true
        }
        
        // Load the reference image
        guard let referenceImage = loadImage(from: referenceImageURL) else {
            XCTFail("Failed to load reference image from \(referenceImageURL.path)")
            return false
        }
        
        // Check that the images have the same dimensions
        guard image.width == referenceImage.width && image.height == referenceImage.height else {
            config.logVerbose("Image dimensions don't match: Test \(image.width)x\(image.height) vs Reference \(referenceImage.width)x\(referenceImage.height)")
            
            if config.saveFailedImages {
                saveImage(image, to: failedImageURL)
            }
            
            XCTFail("Image dimensions don't match: Test \(image.width)x\(image.height) vs Reference \(referenceImage.width)x\(referenceImage.height)")
            return false
        }
        
        // Compare the images
        let (matches, differencePercentage, diffImage) = compareImages(image, referenceImage, tolerance: tolerance)
        
        if !matches {
            config.logVerbose("Images differ by \(differencePercentage * 100)% (tolerance: \(tolerance * 100)%)")
            
            // Save the failed and difference images
            if config.saveFailedImages {
                saveImage(image, to: failedImageURL)
            }
            
            if config.generateDiffImages, let diffImage = diffImage {
                saveImage(diffImage, to: diffImageURL)
            }
            
            // If configured to update reference images automatically, do so
            if config.updateReferenceImagesAutomatically {
                config.logVerbose("Automatically updating reference image: \(referenceImageURL.path)")
                saveImage(image, to: referenceImageURL)
                return true
            }
            
            XCTFail("Images differ by \(differencePercentage * 100)% (tolerance: \(tolerance * 100)%)")
            return false
        }
        
        return true
    }
    
    /// Compares two images and calculates their difference
    /// - Parameters:
    ///   - image1: The first image
    ///   - image2: The second image
    ///   - tolerance: The maximum allowed difference between pixels (0.0-1.0)
    /// - Returns: A tuple containing whether the images match, the difference percentage, and an optional diff image
    static func compareImages(
        _ image1: CGImage,
        _ image2: CGImage,
        tolerance: Double
    ) -> (matches: Bool, differencePercentage: Double, diffImage: CGImage?) {
        // Convert images to CIImage
        let ciImage1 = CIImage(cgImage: image1)
        let ciImage2 = CIImage(cgImage: image2)
        
        // Create a CIFilter to calculate the difference
        guard let differenceFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            return (false, 1.0, nil)
        }
        
        differenceFilter.setValue(ciImage1, forKey: kCIInputImageKey)
        differenceFilter.setValue(ciImage2, forKey: kCIInputBackgroundImageKey)
        
        guard let outputImage = differenceFilter.outputImage else {
            return (false, 1.0, nil)
        }
        
        // Calculate the average difference
        let context = CIContext()
        guard let diffCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return (false, 1.0, nil)
        }
        
        // Analyze the difference image to calculate the percentage difference
        let differencePercentage = calculateDifferencePercentage(diffCGImage)
        
        // Create a more visible diff image for display
        let enhancedDiffImage = enhanceDifferenceImage(diffCGImage)
        
        return (differencePercentage <= tolerance, differencePercentage, enhancedDiffImage)
    }
    
    /// Calculates the percentage difference between two images
    /// - Parameter diffImage: The difference image from compareImages
    /// - Returns: The percentage difference (0.0-1.0)
    static func calculateDifferencePercentage(_ diffImage: CGImage) -> Double {
        let width = diffImage.width
        let height = diffImage.height
        
        // Get the raw image data
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return 1.0
        }
        
        context.draw(diffImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            return 1.0
        }
        
        // Calculate the total difference
        var totalDifference: Double = 0.0
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        let bufferPointer = UnsafeBufferPointer(start: buffer, count: width * height * bytesPerPixel)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                // Get RGB components (ignoring alpha)
                let r = Double(bufferPointer[pixelIndex])
                let g = Double(bufferPointer[pixelIndex + 1])
                let b = Double(bufferPointer[pixelIndex + 2])
                
                // Calculate difference (normalized to 0.0-1.0)
                let pixelDifference = (r + g + b) / (255.0 * 3.0)
                totalDifference += pixelDifference
            }
        }
        
        // Calculate average difference
        return totalDifference / Double(width * height)
    }
    
    /// Enhances a difference image to make differences more visible
    /// - Parameter diffImage: The raw difference image
    /// - Returns: An enhanced image with visible differences
    static func enhanceDifferenceImage(_ diffImage: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: diffImage)
        
        // Apply a color matrix to enhance the visibility of differences
        let colorMatrix = CIFilter(name: "CIColorMatrix")
        colorMatrix?.setValue(ciImage, forKey: kCIInputImageKey)
        colorMatrix?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        colorMatrix?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        colorMatrix?.setValue(CIVector(x: 5, y: 0, z: 0, w: 0), forKey: "inputRVector") // Enhance red channel
        
        guard let enhancedImage = colorMatrix?.outputImage else {
            return diffImage
        }
        
        // Convert back to CGImage
        let context = CIContext()
        return context.createCGImage(enhancedImage, from: enhancedImage.extent)
    }
    
    // MARK: - Image Saving and Loading
    
    /// Saves a CGImage to a file
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: The URL to save the image to
    static func saveImage(_ image: CGImage, to url: URL) {
        let ciImage = CIImage(cgImage: image)
        let context = CIContext()
        
        do {
            try context.writeJPEGRepresentation(
                of: ciImage,
                to: url,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9]
            )
        } catch {
            print("Error saving image to \(url.path): \(error)")
        }
    }
    
    /// Loads a CGImage from a file
    /// - Parameter url: The URL to load the image from
    /// - Returns: The loaded CGImage, or nil if loading failed
    static func loadImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image
    }
    
    // MARK: - Utility Methods
    
    /// Creates a simple colored test image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - color: The RGB color components (0.0-1.0)
    /// - Returns: A CGImage with the specified color
    public static func createTestImage(width: Int, height: Int, color: (red: Double, green: Double, blue: Double)) -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create CGContext")
        }
        
        // Set the fill color
        context.setFillColor(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create the image
        guard let image = context.makeImage() else {
            fatalError("Failed to create image from context")
        }
        
        return image
    }
    
    /// Creates a gradient test image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - startColor: The RGB color at the top (0.0-1.0)
    ///   - endColor: The RGB color at the bottom (0.0-1.0)
    /// - Returns: A CGImage with a vertical gradient
    public static func createGradientImage(
        width: Int,
        height: Int,
        startColor: (red: Double, green: Double, blue: Double),
        endColor: (red: Double, green: Double, blue: Double)
    ) -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create CGContext")
        }
        
        // Create a gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(red: CGFloat(startColor.red), green: CGFloat(startColor.green), blue: CGFloat(startColor.blue), alpha: 1.0),
            CGColor(red: CGFloat(endColor.red), green: CGFloat(endColor.green), blue: CGFloat(endColor.blue), alpha: 1.0)
        ] as CFArray
        
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0.0, 1.0]
        ) else {
            fatalError("Failed to create gradient")
        }
        
        // Draw the gradient
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: height),
            options: []
        )
        
        // Create the image
        guard let image = context.makeImage() else {
            fatalError("Failed to create image from context")
        }
        
        return image
    }
    
    /// Creates a checkerboard pattern image
    /// - Parameters:
    ///   - width: The width of the image
    ///   - height: The height of the image
    ///   - squareSize: The size of each square in pixels
    ///   - color1: The RGB color for odd squares (0.0-1.0)
    ///   - color2: The RGB color for even squares (0.0-1.0)
    /// - Returns: A CGImage with a checkerboard pattern
    public static func createCheckerboardImage(
        width: Int,
        height: Int,
        squareSize: Int,
        color1: (red: Double, green: Double, blue: Double),
        color2: (red: Double, green: Double, blue: Double)
    ) -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create CGContext")
        }
        
        // Set the colors
        let color1CGColor = CGColor(red: CGFloat(color1.red), green: CGFloat(color1.green), blue: CGFloat(color1.blue), alpha: 1.0)
        let color2CGColor = CGColor(red: CGFloat(color2.red), green: CGFloat(color2.green), blue: CGFloat(color2.blue), alpha: 1.0)
        
        // Draw the checkerboard
        for y in stride(from: 0, to: height, by: squareSize) {
            for x in stride(from: 0, to: width, by: squareSize) {
                let isEvenRow = (y / squareSize) % 2 == 0
                let isEvenColumn = (x / squareSize) % 2 == 0
                
                // Set the color based on position
                if isEvenRow != isEvenColumn {
                    context.setFillColor(color1CGColor)
                } else {
                    context.setFillColor(color2CGColor)
                }
                
                // Draw the square
                let squareWidth = min(squareSize, width - x)
                let squareHeight = min(squareSize, height - y)
                context.fill(CGRect(x: x, y: y, width: squareWidth, height: squareHeight))
            }
        }
        
        // Create the image
        guard let image = context.makeImage() else {
            fatalError("Failed to create image from context")
        }
        
        return image
    }
} 