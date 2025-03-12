import Foundation
import XCTest
import CoreGraphics

#if os(macOS)
import AppKit
#endif

/// A utility for visualizing HDR processing results for better debugging of tests
public class HDRResultVisualizer {
    
    /// Shared instance
    public static let shared = HDRResultVisualizer()
    
    /// Output directory for visualizations
    public var outputDirectory: URL {
        let dir = TestConfig.shared.testResultsDir.appendingPathComponent("visualizations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// Visualization options
    public struct VisualizationOptions {
        /// Whether to render false color visualization
        public var falseColor: Bool = true
        /// Whether to show exposure brackets
        public var showExposureBrackets: Bool = true
        /// Whether to include histogram
        public var includeHistogram: Bool = true
        /// Whether to include metadata
        public var includeMetadata: Bool = true
        /// Scale factor for visualization (1.0 = original size)
        public var scaleFactor: Double = 0.5
        
        public static var `default`: VisualizationOptions { VisualizationOptions() }
        
        public init(
            falseColor: Bool = true,
            showExposureBrackets: Bool = true,
            includeHistogram: Bool = true,
            includeMetadata: Bool = true,
            scaleFactor: Double = 0.5
        ) {
            self.falseColor = falseColor
            self.showExposureBrackets = showExposureBrackets
            self.includeHistogram = includeHistogram
            self.includeMetadata = includeMetadata
            self.scaleFactor = scaleFactor
        }
    }
    
    /// Generate a visualization of the HDR processing results
    /// - Parameters:
    ///   - inputImages: The array of input images (usually exposure brackets)
    ///   - outputImage: The final HDR processed image
    ///   - metadata: Optional metadata to include in visualization
    ///   - testName: Name of the test (used for output file name)
    ///   - options: Visualization options
    /// - Returns: URL to the generated visualization
    public func generateVisualization(
        inputImages: [CGImage],
        outputImage: CGImage,
        metadata: [String: Any]? = nil,
        testName: String,
        options: VisualizationOptions = .default
    ) throws -> URL {
        // Calculate visualization dimensions
        let inputWidth = inputImages.first?.width ?? 0
        let inputHeight = inputImages.first?.height ?? 0
        let outputWidth = outputImage.width
        let outputHeight = outputImage.height
        
        let scaledInputWidth = Int(Double(inputWidth) * options.scaleFactor)
        let scaledInputHeight = Int(Double(inputHeight) * options.scaleFactor)
        let scaledOutputWidth = Int(Double(outputWidth) * options.scaleFactor)
        let scaledOutputHeight = Int(Double(outputHeight) * options.scaleFactor)
        
        // Calculate visualization layout
        let margin = 20
        let histogramHeight = options.includeHistogram ? 150 : 0
        let metadataWidth = options.includeMetadata ? 300 : 0
        
        let numInputImages = inputImages.count
        let inputImagesPerRow = min(3, numInputImages)
        let inputImageRows = (numInputImages + inputImagesPerRow - 1) / inputImagesPerRow
        
        let totalWidth = max(
            inputImagesPerRow * scaledInputWidth + (inputImagesPerRow - 1) * margin,
            scaledOutputWidth
        ) + 2 * margin + metadataWidth
        
        let totalHeight = margin + 
                          inputImageRows * scaledInputHeight + 
                          (inputImageRows - 1) * margin +
                          margin +
                          scaledOutputHeight +
                          (options.includeHistogram ? margin + histogramHeight : 0) +
                          margin
        
        // Create image context
        #if os(macOS)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: totalWidth,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        // Fill background
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        
        // Draw title
        drawText(
            in: context,
            text: "HDR Processing Results: \(testName)",
            rect: CGRect(x: margin, y: totalHeight - 30, width: totalWidth - 2 * margin, height: 30),
            attributes: [
                .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                .font: NSFont.boldSystemFont(ofSize: 16)
            ]
        )
        
        // Draw input images
        for i in 0..<numInputImages {
            let row = i / inputImagesPerRow
            let col = i % inputImagesPerRow
            
            let x = margin + col * (scaledInputWidth + margin)
            let y = totalHeight - margin - 40 - (row + 1) * scaledInputHeight - row * margin
            
            if let inputImage = inputImages[i] {
                // Draw image
                context.draw(
                    inputImage,
                    in: CGRect(x: x, y: y, width: scaledInputWidth, height: scaledInputHeight)
                )
                
                // Draw label
                drawText(
                    in: context,
                    text: "Input \(i+1)",
                    rect: CGRect(x: x, y: y - 20, width: scaledInputWidth, height: 20),
                    attributes: [
                        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                        .font: NSFont.systemFont(ofSize: 12)
                    ]
                )
            }
        }
        
        // Draw output image
        let outputY = margin + (options.includeHistogram ? histogramHeight + margin : 0)
        context.draw(
            outputImage,
            in: CGRect(x: margin, y: outputY, width: scaledOutputWidth, height: scaledOutputHeight)
        )
        
        // Draw output label
        drawText(
            in: context,
            text: "HDR Output",
            rect: CGRect(x: margin, y: outputY + scaledOutputHeight, width: scaledOutputWidth, height: 20),
            attributes: [
                .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                .font: NSFont.boldSystemFont(ofSize: 14)
            ]
        )
        
        // Draw histogram if requested
        if options.includeHistogram {
            drawHistogram(
                of: outputImage,
                in: context,
                rect: CGRect(x: margin, y: margin, width: scaledOutputWidth, height: histogramHeight)
            )
        }
        
        // Draw metadata if requested
        if options.includeMetadata, let metadata = metadata {
            drawMetadata(
                metadata,
                in: context,
                rect: CGRect(
                    x: totalWidth - margin - metadataWidth,
                    y: margin,
                    width: metadataWidth,
                    height: totalHeight - 2 * margin
                )
            )
        }
        
        // Generate image from context
        guard let resultImage = context.makeImage() else {
            throw NSError(domain: "HDRResultVisualizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create visualization image"])
        }
        
        // Save to file
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputURL = outputDirectory.appendingPathComponent("\(testName)_visualization_\(timestamp).png")
        
        let nsImage = NSImage(cgImage: resultImage, size: NSSize(width: totalWidth, height: totalHeight))
        guard let data = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "HDRResultVisualizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert visualization to PNG"])
        }
        
        try pngData.write(to: outputURL)
        
        return outputURL
        #else
        // For non-macOS platforms
        throw NSError(domain: "HDRResultVisualizer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Visualization is currently only supported on macOS"])
        #endif
    }
    
    // MARK: - Private Drawing Methods
    
    #if os(macOS)
    /// Draw text in the context
    private func drawText(
        in context: CGContext,
        text: String,
        rect: CGRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
        
        context.saveGState()
        // Flip the coordinate system
        context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -rect.origin.y)
        
        attributedString.draw(in: textRect)
        context.restoreGState()
    }
    
    /// Draw a histogram for the image
    private func drawHistogram(
        of image: CGImage,
        in context: CGContext,
        rect: CGRect
    ) {
        // Calculate histogram
        let histogram = calculateHistogram(for: image)
        
        // Draw background
        context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
        context.fill(rect)
        
        // Draw border
        context.setStrokeColor(CGColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0))
        context.setLineWidth(1)
        context.stroke(rect)
        
        // Draw title
        drawText(
            in: context,
            text: "Histogram",
            rect: CGRect(x: rect.origin.x + 5, y: rect.origin.y + rect.size.height - 20, width: rect.size.width - 10, height: 20),
            attributes: [
                .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                .font: NSFont.boldSystemFont(ofSize: 12)
            ]
        )
        
        // Calculate max value for scaling
        let maxValue = max(
            histogram.red.max() ?? 1,
            histogram.green.max() ?? 1,
            histogram.blue.max() ?? 1
        )
        
        // Draw histogram
        let histogramRect = CGRect(
            x: rect.origin.x + 10,
            y: rect.origin.y + 25,
            width: rect.size.width - 20,
            height: rect.size.height - 50
        )
        
        // Draw red channel
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.8))
        drawHistogramChannel(histogram.red, in: context, rect: histogramRect, maxValue: maxValue)
        
        // Draw green channel
        context.setStrokeColor(CGColor(red: 0, green: 1, blue: 0, alpha: 0.8))
        drawHistogramChannel(histogram.green, in: context, rect: histogramRect, maxValue: maxValue)
        
        // Draw blue channel
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: 0.8))
        drawHistogramChannel(histogram.blue, in: context, rect: histogramRect, maxValue: maxValue)
        
        // Draw axis labels
        drawText(
            in: context,
            text: "0",
            rect: CGRect(x: histogramRect.origin.x - 5, y: histogramRect.origin.y - 15, width: 20, height: 12),
            attributes: [
                .foregroundColor: CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1),
                .font: NSFont.systemFont(ofSize: 10)
            ]
        )
        
        drawText(
            in: context,
            text: "255",
            rect: CGRect(x: histogramRect.origin.x + histogramRect.size.width - 15, y: histogramRect.origin.y - 15, width: 30, height: 12),
            attributes: [
                .foregroundColor: CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1),
                .font: NSFont.systemFont(ofSize: 10)
            ]
        )
    }
    
    /// Draw a single histogram channel
    private func drawHistogramChannel(
        _ values: [Int],
        in context: CGContext,
        rect: CGRect,
        maxValue: Int
    ) {
        context.saveGState()
        
        let path = CGMutablePath()
        let count = values.count
        let width = rect.size.width
        let height = rect.size.height
        
        // Start at bottom left
        path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
        
        // Draw histogram points
        for i in 0..<count {
            let x = rect.origin.x + CGFloat(i) * width / CGFloat(count - 1)
            let value = CGFloat(values[i]) / CGFloat(maxValue)
            let y = rect.origin.y + value * height
            
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Complete the path back to the origin
        path.addLine(to: CGPoint(x: rect.origin.x + width, y: rect.origin.y))
        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
        
        // Fill with gradient
        context.addPath(path)
        context.clip()
        
        let colors = [
            context.strokeColor?.copy(alpha: 0.1) ?? CGColor(red: 1, green: 1, blue: 1, alpha: 0.1),
            context.strokeColor?.copy(alpha: 0.4) ?? CGColor(red: 1, green: 1, blue: 1, alpha: 0.4)
        ] as CFArray
        
        let locations: [CGFloat] = [0.0, 1.0]
        
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: []
            )
        }
        
        // Stroke the outline
        context.setLineWidth(1.0)
        context.setLineJoin(.round)
        
        let outlinePath = CGMutablePath()
        
        // Just the top line for the outline
        for i in 0..<count {
            let x = rect.origin.x + CGFloat(i) * width / CGFloat(count - 1)
            let value = CGFloat(values[i]) / CGFloat(maxValue)
            let y = rect.origin.y + value * height
            
            if i == 0 {
                outlinePath.move(to: CGPoint(x: x, y: y))
            } else {
                outlinePath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.addPath(outlinePath)
        context.strokePath()
        
        context.restoreGState()
    }
    
    /// Draw metadata
    private func drawMetadata(
        _ metadata: [String: Any],
        in context: CGContext,
        rect: CGRect
    ) {
        // Draw background
        context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
        context.fill(rect)
        
        // Draw border
        context.setStrokeColor(CGColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0))
        context.setLineWidth(1)
        context.stroke(rect)
        
        // Draw title
        drawText(
            in: context,
            text: "Metadata",
            rect: CGRect(x: rect.origin.x + 5, y: rect.origin.y + rect.size.height - 20, width: rect.size.width - 10, height: 20),
            attributes: [
                .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                .font: NSFont.boldSystemFont(ofSize: 12)
            ]
        )
        
        // Draw metadata entries
        let contentRect = CGRect(
            x: rect.origin.x + 10,
            y: rect.origin.y + 10,
            width: rect.size.width - 20,
            height: rect.size.height - 40
        )
        
        var yOffset = contentRect.origin.y + contentRect.size.height - 15
        
        // Sort metadata keys
        let sortedKeys = metadata.keys.sorted()
        
        for key in sortedKeys {
            let value = metadata[key]
            let valueStr = String(describing: value ?? "nil")
            
            // Draw key
            drawText(
                in: context,
                text: "\(key):",
                rect: CGRect(x: contentRect.origin.x, y: yOffset - 15, width: contentRect.size.width, height: 15),
                attributes: [
                    .foregroundColor: CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
                    .font: NSFont.boldSystemFont(ofSize: 11)
                ]
            )
            
            // Draw value (possibly multiline)
            let valueLines = valueStr.split(separator: "\n")
            for (i, line) in valueLines.enumerated() {
                drawText(
                    in: context,
                    text: String(line),
                    rect: CGRect(x: contentRect.origin.x + 10, y: yOffset - 30 - CGFloat(i * 15), width: contentRect.size.width - 10, height: 15),
                    attributes: [
                        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                        .font: NSFont.systemFont(ofSize: 10)
                    ]
                )
            }
            
            yOffset -= 15 + CGFloat(valueLines.count * 15) + 10
            
            // Check if we've run out of space
            if yOffset < contentRect.origin.y {
                drawText(
                    in: context,
                    text: "... more metadata not shown ...",
                    rect: CGRect(x: contentRect.origin.x, y: contentRect.origin.y, width: contentRect.size.width, height: 15),
                    attributes: [
                        .foregroundColor: CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1),
                        .font: NSFont.italicSystemFont(ofSize: 10)
                    ]
                )
                break
            }
        }
    }
    #endif
    
    // MARK: - Image Analysis
    
    /// Structure to hold histogram data
    private struct Histogram {
        var red: [Int]
        var green: [Int]
        var blue: [Int]
        
        init() {
            red = Array(repeating: 0, count: 256)
            green = Array(repeating: 0, count: 256)
            blue = Array(repeating: 0, count: 256)
        }
    }
    
    /// Calculate histogram for an image
    private func calculateHistogram(for image: CGImage) -> Histogram {
        var histogram = Histogram()
        
        // Get image data
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return histogram
        }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        
        guard let data = context.data else {
            return histogram
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        // Sample pixels (only analyze every 4th pixel for performance)
        let samplingRate = 4
        let samplingFactor = samplingRate * samplingRate
        
        for y in stride(from: 0, to: height, by: samplingRate) {
            for x in stride(from: 0, to: width, by: samplingRate) {
                let offset = (y * width + x) * bytesPerPixel
                
                histogram.red[Int(buffer[offset])] += samplingFactor
                histogram.green[Int(buffer[offset + 1])] += samplingFactor
                histogram.blue[Int(buffer[offset + 2])] += samplingFactor
            }
        }
        
        return histogram
    }
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    /// Generate a visualization of the HDR processing results
    /// - Parameters:
    ///   - inputImages: The array of input images (usually exposure brackets)
    ///   - outputImage: The final HDR processed image
    ///   - metadata: Optional metadata to include in visualization
    ///   - options: Visualization options
    /// - Returns: URL to the generated visualization
    @discardableResult
    public func generateHDRVisualization(
        inputImages: [CGImage],
        outputImage: CGImage,
        metadata: [String: Any]? = nil,
        options: HDRResultVisualizer.VisualizationOptions = .default
    ) throws -> URL {
        // Get the test name
        let testName = String(reflecting: type(of: self)) + "." + name
        
        return try HDRResultVisualizer.shared.generateVisualization(
            inputImages: inputImages,
            outputImage: outputImage,
            metadata: metadata,
            testName: testName,
            options: options
        )
    }
} 